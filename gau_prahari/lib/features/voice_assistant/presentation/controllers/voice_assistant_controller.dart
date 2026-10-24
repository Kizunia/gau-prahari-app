import 'package:flutter/foundation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../domain/services/assistant_responder.dart';
import '../../domain/services/speech_output_service.dart';
import '../../domain/services/speech_recognition_service.dart';

enum VoiceAssistantStatus { idle, listening, processing, speaking, error }

/// Controller managing the voice assistant state, speech coordination,
/// and conversation persistence.
class VoiceAssistantController extends ChangeNotifier {
  final ConversationRepository _conversationRepository;
  final SpeechRecognitionService _speechRecognitionService;
  final SpeechOutputService _speechOutputService;
  final AssistantResponder _responder;

  VoiceAssistantStatus _status = VoiceAssistantStatus.idle;
  Conversation? _activeConversation;
  List<ChatMessage> _messages = [];
  List<Conversation> _previousConversations = [];
  String? _currentTranscript;
  String? _errorMessage;
  String? _ownerId;
  bool _isInitialized = false;
  int _sessionToken = 0;

  VoiceAssistantController({
    required ConversationRepository conversationRepository,
    required SpeechRecognitionService speechRecognitionService,
    required SpeechOutputService speechOutputService,
    required AssistantResponder responder,
  }) : _conversationRepository = conversationRepository,
       _speechRecognitionService = speechRecognitionService,
       _speechOutputService = speechOutputService,
       _responder = responder;

  VoiceAssistantStatus get status => _status;
  Conversation? get activeConversation => _activeConversation;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<Conversation> get previousConversations =>
      List.unmodifiable(_previousConversations);
  String? get currentTranscript => _currentTranscript;
  String? get errorMessage => _errorMessage;
  String? get ownerId => _ownerId;
  bool get isInitialized => _isInitialized;

  bool get isListening => _status == VoiceAssistantStatus.listening;
  bool get isProcessing => _status == VoiceAssistantStatus.processing;
  bool get isSpeaking => _status == VoiceAssistantStatus.speaking;
  bool get isIdle => _status == VoiceAssistantStatus.idle;

  /// Initialize the controller for the specified [currentOwnerId].
  /// Restores the last opened conversation if available.
  Future<void> init({String? currentOwnerId}) async {
    // If owner changed or not yet initialized
    if (_isInitialized && _ownerId == currentOwnerId) return;

    _ownerId = currentOwnerId;
    _status = VoiceAssistantStatus.idle;
    _errorMessage = null;

    try {
      await _loadPreviousConversations();

      // Restore last opened conversation for this owner
      final lastConv = await _conversationRepository.getLastOpenedConversation(
        ownerId: _ownerId,
      );
      if (lastConv != null) {
        _activeConversation = lastConv;
        _messages = await _conversationRepository.getMessages(lastConv.id);
      } else {
        _activeConversation = null;
        _messages = [];
      }
    } catch (e) {
      debugPrint('VoiceAssistantController init error: $e');
      _errorMessage = 'dbInitError';
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadPreviousConversations() async {
    try {
      _previousConversations = await _conversationRepository.getConversations(
        ownerId: _ownerId,
      );
    } catch (e) {
      debugPrint('Error loading previous conversations: $e');
    }
  }

  /// Start a brand new conversation without deleting previous history.
  Future<void> startNewConversation() async {
    await stopSpeaking();
    await cancelListening();

    _activeConversation = null;
    _messages = [];
    _currentTranscript = null;
    _errorMessage = null;
    _status = VoiceAssistantStatus.idle;
    notifyListeners();
  }

  /// Reopen an older conversation from history.
  Future<void> openConversation(String conversationId) async {
    await stopSpeaking();
    await cancelListening();

    try {
      final conv = await _conversationRepository.getConversationById(
        conversationId,
      );
      if (conv != null) {
        _activeConversation = conv;
        _messages = await _conversationRepository.getMessages(conversationId);
        await _conversationRepository.markConversationOpened(conversationId);
        await _loadPreviousConversations();
      }
    } catch (e) {
      debugPrint('Error opening conversation $conversationId: $e');
      _errorMessage = 'dbError';
    }

    _currentTranscript = null;
    _errorMessage = null;
    _status = VoiceAssistantStatus.idle;
    notifyListeners();
  }

  /// Delete a conversation and refresh history.
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _conversationRepository.deleteConversation(conversationId);
      if (_activeConversation?.id == conversationId) {
        _activeConversation = null;
        _messages = [];
      }
      await _loadPreviousConversations();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  /// Toggle or start listening for voice input.
  Future<void> toggleListening({required String languageCode}) async {
    if (_status == VoiceAssistantStatus.listening) {
      await stopListening();
    } else if (_status == VoiceAssistantStatus.speaking) {
      await stopSpeaking();
    } else if (_status == VoiceAssistantStatus.idle ||
        _status == VoiceAssistantStatus.error) {
      await startListening(languageCode: languageCode);
    }
  }

  /// Start listening for voice input in [languageCode].
  Future<void> startListening({required String languageCode}) async {
    if (_status == VoiceAssistantStatus.listening ||
        _status == VoiceAssistantStatus.processing) {
      return;
    }

    // Stop previous TTS
    await _speechOutputService.stop();

    final currentSession = ++_sessionToken;
    _errorMessage = null;
    _currentTranscript = '';
    _status = VoiceAssistantStatus.listening;
    notifyListeners();

    try {
      final hasPerm = await _speechRecognitionService.hasPermission();
      if (!hasPerm) {
        // Try initializing which requests permission if needed
        final ok = await _speechRecognitionService.initialize();
        if (!ok) {
          if (_sessionToken == currentSession) {
            _status = VoiceAssistantStatus.error;
            _errorMessage = 'permissionDenied';
            notifyListeners();
          }
          return;
        }
      }

      await _speechRecognitionService.startListening(
        languageCode: languageCode,
        onResult: (words, isFinal) {
          if (_sessionToken != currentSession) return;

          _currentTranscript = words;
          notifyListeners();

          if (isFinal) {
            _processQuery(
              words,
              languageCode: languageCode,
              sessionToken: currentSession,
            );
          }
        },
        onError: (err) {
          if (_sessionToken != currentSession) return;
          debugPrint('Recognition error: $err');
          _status = VoiceAssistantStatus.error;
          _errorMessage = err.contains('error_no_match')
              ? 'noSpeechDetected'
              : 'speechError';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Error starting listening: $e');
      if (_sessionToken == currentSession) {
        _status = VoiceAssistantStatus.error;
        _errorMessage = 'speechError';
        notifyListeners();
      }
    }
  }

  /// Stop listening and finalize recognition.
  Future<void> stopListening() async {
    if (_status != VoiceAssistantStatus.listening) return;

    final session = _sessionToken;
    final words = _currentTranscript ?? '';
    await _speechRecognitionService.stopListening();

    if (_sessionToken == session) {
      await _processQuery(words, languageCode: 'en', sessionToken: session);
    }
  }

  /// Cancel listening and discard partial text.
  Future<void> cancelListening() async {
    _sessionToken++;
    if (_speechRecognitionService.isListening) {
      await _speechRecognitionService.cancelListening();
    }
    _currentTranscript = null;
    _status = VoiceAssistantStatus.idle;
    notifyListeners();
  }

  /// Stop ongoing TTS speaking.
  Future<void> stopSpeaking() async {
    _sessionToken++;
    await _speechOutputService.stop();
    if (_status == VoiceAssistantStatus.speaking) {
      _status = VoiceAssistantStatus.idle;
      notifyListeners();
    }
  }

  /// Submit a query directly (supports programmatic calls or touch input).
  Future<void> submitQuery(String query, {required String languageCode}) async {
    if (query.trim().isEmpty) return;
    await stopSpeaking();
    final currentSession = ++_sessionToken;
    await _processQuery(
      query,
      languageCode: languageCode,
      sessionToken: currentSession,
    );
  }

  Future<void> _processQuery(
    String query, {
    required String languageCode,
    required int sessionToken,
  }) async {
    _debugLog('processing_started');
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      if (_sessionToken == sessionToken) {
        _status = VoiceAssistantStatus.idle;
        _errorMessage = 'noSpeechDetected';
        _currentTranscript = null;
        notifyListeners();
      }
      return;
    }

    _status = VoiceAssistantStatus.processing;
    _currentTranscript = null;
    notifyListeners();

    try {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // 1. Create conversation if none active
      if (_activeConversation == null) {
        final title = cleanQuery.length > 30
            ? '${cleanQuery.substring(0, 30)}...'
            : cleanQuery;
        _activeConversation = await _conversationRepository.createConversation(
          ownerId: _ownerId,
          title: title,
        );
      }

      // 2. Persist user message
      final userMessage = ChatMessage(
        id: '',
        conversationId: _activeConversation!.id,
        role: 'user',
        content: cleanQuery,
        createdAt: now,
      );
      final savedUserMsg = await _conversationRepository.addMessage(
        userMessage,
      );
      _messages.add(savedUserMsg);
      _debugLog('user_message_persisted');
      notifyListeners();

      // 3. Load only the active conversation's latest 20 messages for Gemini.
      final recentMessages = await _conversationRepository.getRecentMessages(
        _activeConversation!.id,
        limit: 20,
      );

      // 4. Generate a response; the responder uses no app actions in Phase 2.
      _debugLog('responder_call_start');
      final replyText = await _responder.respond(
        query: cleanQuery,
        languageCode: languageCode,
        conversationContext: recentMessages,
      );
      _debugLog('responder_returned reply_length=${replyText.length}');

      // Verify session wasn't cancelled while processing
      if (_sessionToken != sessionToken) return;

      // 5. Persist assistant response (including a clear service fallback).
      final assistantMessage = ChatMessage(
        id: '',
        conversationId: _activeConversation!.id,
        role: 'assistant',
        content: replyText,
        createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
      final savedAssistantMsg = await _conversationRepository.addMessage(
        assistantMessage,
      );
      _messages.add(savedAssistantMsg);
      _debugLog('assistant_message_persisted');
      await _loadPreviousConversations();

      // 6. Speak response aloud
      _status = VoiceAssistantStatus.speaking;
      notifyListeners();

      await _speechOutputService.speak(
        replyText,
        languageCode: languageCode,
        onDone: () {
          if (_sessionToken == sessionToken) {
            _status = VoiceAssistantStatus.idle;
            notifyListeners();
          }
        },
      );
    } catch (e) {
      _debugLog('processing_failed exception_type=${e.runtimeType}');
      if (_sessionToken == sessionToken) {
        _status = VoiceAssistantStatus.error;
        _errorMessage = 'processingError';
        notifyListeners();
      }
    }
  }

  /// Clear any active error message.
  void clearError() {
    _errorMessage = null;
    if (_status == VoiceAssistantStatus.error) {
      _status = VoiceAssistantStatus.idle;
    }
    notifyListeners();
  }

  void _debugLog(String message) {
    if (kDebugMode) debugPrint('[VoiceAssistant] $message');
  }
}
