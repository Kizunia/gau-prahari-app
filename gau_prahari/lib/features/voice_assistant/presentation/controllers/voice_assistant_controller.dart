import 'package:flutter/foundation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../domain/services/assistant_responder.dart';
import '../../domain/services/speech_output_service.dart';
import '../../domain/services/speech_recognition_service.dart';
import '../../data/services/ai_assistant_service.dart';

enum VoiceAssistantStatus { idle, listening, processing, speaking, error }

/// Controller managing the voice assistant state, speech coordination,
/// conversation persistence, screen-context, and actionable intents.
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

  // Processing guards to prevent duplicate invocations and races
  int? _activeProcessingSession;
  String? _lastProcessedQuery;
  int? _lastProcessedTimestamp;

  Map<String, dynamic>? _screenContext;
  String? _pendingAction;
  String? _listeningLanguage;

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
  Map<String, dynamic>? get screenContext => _screenContext;
  String? get pendingAction => _pendingAction;

  bool get isListening => _status == VoiceAssistantStatus.listening;
  bool get isProcessing =>
      _status == VoiceAssistantStatus.processing ||
      _activeProcessingSession != null;
  bool get isSpeaking => _status == VoiceAssistantStatus.speaking;
  bool get isIdle => _status == VoiceAssistantStatus.idle;

  /// Update the current screen context for context-aware assistance.
  void setScreenContext({
    required String screenName,
    Map<String, dynamic>? contextData,
  }) {
    _screenContext = {
      'screenName': screenName,
      if (contextData != null) ...contextData,
    };
    notifyListeners();
  }

  /// Clear screen context when leaving the workflow.
  void clearScreenContext() {
    _screenContext = null;
    notifyListeners();
  }

  /// Clear any pending action once dispatched by UI.
  void clearPendingAction() {
    _pendingAction = null;
    notifyListeners();
  }

  /// Initialize the controller for the specified [currentOwnerId].
  /// Restores the last opened conversation if available.
  Future<void> init({String? currentOwnerId}) async {
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
    _pendingAction = null;
    _lastProcessedQuery = null;
    _lastProcessedTimestamp = null;
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
    _pendingAction = null;
    _lastProcessedQuery = null;
    _lastProcessedTimestamp = null;
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
    if (isProcessing) {
      return;
    }
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
    if (_status == VoiceAssistantStatus.listening || isProcessing) {
      return;
    }

    // Stop previous TTS
    await _speechOutputService.stop();

    final currentSession = ++_sessionToken;
    _listeningLanguage = languageCode;
    _errorMessage = null;
    _currentTranscript = '';
    _status = VoiceAssistantStatus.listening;
    notifyListeners();

    try {
      final hasPerm = await _speechRecognitionService.hasPermission();
      if (!hasPerm) {
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
            final cleanWords = words.trim();
            _currentTranscript = null;
            _speechRecognitionService.stopListening().catchError((_) {});

            if (cleanWords.isEmpty) {
              _status = VoiceAssistantStatus.idle;
              _errorMessage = 'noSpeechDetected';
              notifyListeners();
              return;
            }

            if (isProcessing) {
              debugPrint('Ignoring isFinal: already processing.');
              return;
            }

            _status = VoiceAssistantStatus.processing;

            final querySession = ++_sessionToken;
            _activeProcessingSession = querySession;
            _processQuery(
              cleanWords,
              languageCode: languageCode,
              sessionToken: querySession,
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

    final query = (_currentTranscript ?? '').trim();
    _currentTranscript = null;
    _status = VoiceAssistantStatus.idle;

    if (query.isEmpty) {
      _errorMessage = 'noSpeechDetected';
      notifyListeners();
      return;
    }

    if (isProcessing) {
      debugPrint('Ignoring stopListening query: already processing.');
      return;
    }

    _status = VoiceAssistantStatus.processing;

    try {
      await _speechRecognitionService.stopListening();
    } catch (e) {
      debugPrint('Error stopping speech recognition: $e');
    }

    final querySession = ++_sessionToken;
    _activeProcessingSession = querySession;

    await _processQuery(
      query,
      languageCode: _listeningLanguage ?? 'en',
      sessionToken: querySession,
    );
  }

  /// Cancel listening and discard partial text.
  Future<void> cancelListening() async {
    _sessionToken++;
    try {
      if (_speechRecognitionService.isListening) {
        await _speechRecognitionService.cancelListening();
      }
    } catch (e) {
      debugPrint('Error canceling speech recognition: $e');
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
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    if (isProcessing) {
      debugPrint('Ignoring submitQuery: query is already being processed.');
      return;
    }

    // Debounce rapid duplicate query submissions
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastProcessedQuery == cleanQuery &&
        _lastProcessedTimestamp != null &&
        (nowMs - _lastProcessedTimestamp!) < 2000) {
      debugPrint('Discarding duplicate query in rapid succession: $cleanQuery');
      return;
    }

    _status = VoiceAssistantStatus.processing;
    _lastProcessedQuery = cleanQuery;
    _lastProcessedTimestamp = nowMs;
    _listeningLanguage = languageCode;

    await stopSpeaking();
    if (_status == VoiceAssistantStatus.listening) {
      await cancelListening();
    }

    final currentSession = ++_sessionToken;
    _activeProcessingSession = currentSession;

    await _processQuery(
      cleanQuery,
      languageCode: languageCode,
      sessionToken: currentSession,
    );
  }

  String? _detectAction(String query, String rawReply) {
    if (rawReply.contains('[ACTION:scan_cow]')) return 'scan_cow';
    final q = query.toLowerCase();
    if (q.contains('scan cow') ||
        q.contains('scan a cow') ||
        q.contains('qr scan') ||
        q.contains('scan qr') ||
        q.contains('open scanner') ||
        q.contains('open qr') ||
        q.contains('गाय स्कैन') ||
        q.contains('स्कैनर खोलो') ||
        q.contains('गाय स्कॅन') ||
        q.contains('स्कॅनर उघडा')) {
      return 'scan_cow';
    }
    return null;
  }

  Future<void> _processQuery(
    String query, {
    required String languageCode,
    required int sessionToken,
  }) async {
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

    if (_activeProcessingSession != null &&
        _activeProcessingSession != sessionToken) {
      debugPrint('Ignoring duplicate query processing: already processing.');
      return;
    }

    _activeProcessingSession = sessionToken;
    _lastProcessedQuery = cleanQuery;
    _lastProcessedTimestamp = DateTime.now().millisecondsSinceEpoch;

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
        screenName: _screenContext?['screenName'] as String?,
      );
      final savedUserMsg = await _conversationRepository.addMessage(
        userMessage,
      );
      _messages.add(savedUserMsg);
      notifyListeners();

      // 3. Generate response using responder (Gemini or Local)
      final rawReply = await _responder.respond(
        query: cleanQuery,
        languageCode: languageCode,
        conversationContext: _messages,
        screenContext: _screenContext,
      );

      // Verify session wasn't cancelled while processing
      if (_sessionToken != sessionToken) return;

      final detectedAction = _detectAction(cleanQuery, rawReply);
      final replyText = rawReply.replaceAll('[ACTION:scan_cow]', '').trim();
      _pendingAction = detectedAction;

      // 4. Persist assistant response
      final assistantMessage = ChatMessage(
        id: '',
        conversationId: _activeConversation!.id,
        role: 'assistant',
        content: replyText,
        createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        screenName: _screenContext?['screenName'] as String?,
        actionName: detectedAction,
        actionStatus: detectedAction != null ? 'succeeded' : null,
      );
      final savedAssistantMsg = await _conversationRepository.addMessage(
        assistantMessage,
      );
      _messages.add(savedAssistantMsg);
      await _loadPreviousConversations();

      // 5. Speak response aloud
      _status = VoiceAssistantStatus.speaking;
      notifyListeners();

      String ttsLang = languageCode;
      if (languageCode == 'hi') {
        ttsLang = 'hi';
      } else if (languageCode == 'mr') {
        ttsLang = 'mr';
      } else if (RegExp(r'[\u0900-\u097F]').hasMatch(replyText)) {
        if (AiAssistantService.isMarathiQuery(cleanQuery) ||
            replyText.contains('आहे') ||
            replyText.contains('नाही') ||
            replyText.contains('माहिती') ||
            replyText.contains('दिवशी') ||
            replyText.contains('वर्षांची') ||
            replyText.contains('सांगा')) {
          ttsLang = 'mr';
        } else {
          ttsLang = 'hi';
        }
      }

      await _speechOutputService.speak(
        replyText,
        languageCode: ttsLang,
        onDone: () {
          if (_sessionToken == sessionToken) {
            _status = VoiceAssistantStatus.idle;
            notifyListeners();
          }
        },
      );
    } catch (e) {
      debugPrint('Error processing voice query: $e');
      if (_sessionToken == sessionToken) {
        _status = VoiceAssistantStatus.error;
        _errorMessage = 'processingError';
        notifyListeners();
      }
    } finally {
      if (_activeProcessingSession == sessionToken) {
        _activeProcessingSession = null;
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
}
