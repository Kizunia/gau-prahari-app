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
  static int _globalInteractionSequence = 0;
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
  int? _claimedListeningSession;
  bool _queryInFlight = false;
  bool _startingListening = false;
  bool _startingTextSubmission = false;
  String? _listeningRequestId;
  String _listeningLanguageCode = 'en';
  Future<void>? _activeListeningQuery;

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
        _status == VoiceAssistantStatus.processing ||
        _startingListening ||
        _startingTextSubmission ||
        _queryInFlight) {
      return;
    }

    // Stop previous TTS
    _startingListening = true;
    try {
      await _speechOutputService.stop();
    } finally {
      _startingListening = false;
    }

    // A second call can have changed state while the speech output stopped.
    if (_status == VoiceAssistantStatus.listening ||
        _status == VoiceAssistantStatus.processing ||
        _startingTextSubmission ||
        _queryInFlight) {
      return;
    }

    final currentSession = ++_sessionToken;
    final requestId = _newRequestId();
    _listeningRequestId = requestId;
    _listeningLanguageCode = languageCode;
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
          if (_claimedListeningSession == currentSession) {
            _debugLog(requestId, 'duplicate_recognition_callback_ignored');
            return;
          }

          _currentTranscript = words;
          notifyListeners();

          if (isFinal) {
            if (_claimListeningSession(currentSession, requestId)) {
              _launchListeningQuery(
                words,
                languageCode: languageCode,
                sessionToken: currentSession,
                requestId: requestId,
              );
            }
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
    if (_status != VoiceAssistantStatus.listening) {
      // A final callback may already have claimed this session while the
      // platform recognizer is still winding down. Stop it without resubmitting.
      if (_claimedListeningSession == _sessionToken &&
          _speechRecognitionService.isListening) {
        await _speechRecognitionService.stopListening();
      }
      if (_claimedListeningSession == _sessionToken) {
        await _activeListeningQuery;
      }
      return;
    }

    final session = _sessionToken;
    final requestId = _listeningRequestId ?? _newRequestId();
    await _speechRecognitionService.stopListening();

    if (_sessionToken != session || _claimedListeningSession == session) {
      if (_claimedListeningSession == session) {
        await _activeListeningQuery;
      }
      return;
    }

    // stop() can deliver a final result before its Future completes. If no
    // final result claimed this session, submit the freshest partial once.
    final words = _currentTranscript ?? '';
    if (_claimListeningSession(session, requestId)) {
      await _launchListeningQuery(
        words,
        languageCode: _listeningLanguageCode,
        sessionToken: session,
        requestId: requestId,
      );
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
    if (_queryInFlight || _startingTextSubmission) {
      _debugLog(_newRequestId(), 'query_rejected reason=interaction_in_flight');
      return;
    }
    final requestId = _newRequestId();
    _startingTextSubmission = true;
    try {
      await stopSpeaking();
      final currentSession = ++_sessionToken;
      await _processQuery(
        query,
        languageCode: languageCode,
        sessionToken: currentSession,
        requestId: requestId,
      );
    } finally {
      _startingTextSubmission = false;
    }
  }

  Future<void> _processQuery(
    String query, {
    required String languageCode,
    required int sessionToken,
    required String requestId,
  }) async {
    _debugLog(requestId, 'processing_started');
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

    if (_queryInFlight) {
      _debugLog(requestId, 'processing_rejected reason=interaction_in_flight');
      return;
    }
    _queryInFlight = true;

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
      _debugLog(requestId, 'user_message_persisted');
      notifyListeners();

      // 3. Load only the active conversation's latest 20 messages for Gemini.
      final recentMessages = await _conversationRepository.getRecentMessages(
        _activeConversation!.id,
        limit: 20,
      );

      // 4. Generate a response; the responder uses no app actions in Phase 2.
      _debugLog(requestId, 'responder_call_start');
      final replyText = await _responder.respond(
        query: cleanQuery,
        languageCode: languageCode,
        conversationContext: recentMessages,
        requestId: requestId,
      );
      _debugLog(
        requestId,
        'responder_returned reply_length=${replyText.length}',
      );

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
      _debugLog(requestId, 'assistant_message_persisted');
      await _loadPreviousConversations();

      // 6. Speak response aloud
      _queryInFlight = false;
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
    } catch (e, stackTrace) {
      _debugLog(requestId, 'processing_failed exception_type=${e.runtimeType}');
      if (kDebugMode) {
        debugPrintStack(
          stackTrace: stackTrace,
          label:
              '[VoiceAssistant] request_id=$requestId processing_failed_stack',
        );
      }
      if (_sessionToken == sessionToken) {
        _status = VoiceAssistantStatus.error;
        _errorMessage = 'processingError';
        notifyListeners();
      }
    } finally {
      _queryInFlight = false;
    }
  }

  Future<void> _launchListeningQuery(
    String query, {
    required String languageCode,
    required int sessionToken,
    required String requestId,
  }) {
    final task = _processQuery(
      query,
      languageCode: languageCode,
      sessionToken: sessionToken,
      requestId: requestId,
    );
    _activeListeningQuery = task;
    task.whenComplete(() {
      if (identical(_activeListeningQuery, task)) {
        _activeListeningQuery = null;
      }
    });
    return task;
  }

  /// Clear any active error message.
  void clearError() {
    _errorMessage = null;
    if (_status == VoiceAssistantStatus.error) {
      _status = VoiceAssistantStatus.idle;
    }
    notifyListeners();
  }

  bool _claimListeningSession(int session, String requestId) {
    if (_claimedListeningSession == session) {
      _debugLog(requestId, 'duplicate_listening_session_ignored');
      return false;
    }
    _claimedListeningSession = session;
    return true;
  }

  String _newRequestId() {
    _globalInteractionSequence++;
    return 'va-${DateTime.now().microsecondsSinceEpoch}-$_globalInteractionSequence';
  }

  void _debugLog(String requestId, String message) {
    if (kDebugMode) {
      debugPrint('[VoiceAssistant] request_id=$requestId $message');
    }
  }
}
