import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gau_prahari/features/voice_assistant/data/database/conversation_database.dart';
import 'package:gau_prahari/features/voice_assistant/data/repositories/conversation_repository_impl.dart';
import 'package:gau_prahari/features/voice_assistant/domain/entities/chat_message.dart';
import 'package:gau_prahari/features/voice_assistant/domain/repositories/conversation_repository.dart';
import 'package:gau_prahari/features/voice_assistant/domain/services/assistant_responder.dart';
import 'package:gau_prahari/features/voice_assistant/domain/services/speech_output_service.dart';
import 'package:gau_prahari/features/voice_assistant/domain/services/speech_recognition_service.dart';
import 'package:gau_prahari/features/voice_assistant/presentation/controllers/voice_assistant_controller.dart';

/// Fake implementation of [SpeechRecognitionService] for unit testing.
class FakeSpeechRecognitionService implements SpeechRecognitionService {
  bool _isListening = false;
  final bool _isAvailable = true;
  bool hasPermissionResult = true;
  bool initializeResult = true;
  Function(String recognizedWords, bool isFinal)? lastOnResult;
  Function(String error)? lastOnError;
  String? lastStartedLanguage;
  int startListeningCallCount = 0;
  int stopListeningCallCount = 0;
  int cancelListeningCallCount = 0;

  @override
  bool get isListening => _isListening;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<bool> initialize({
    Function(String error)? onError,
    Function(String status)? onStatus,
  }) async {
    return hasPermissionResult && initializeResult;
  }

  @override
  Future<bool> hasPermission() async {
    return hasPermissionResult;
  }

  @override
  Future<void> startListening({
    required String languageCode,
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(String error)? onError,
  }) async {
    startListeningCallCount++;
    _isListening = true;
    lastStartedLanguage = languageCode;
    lastOnResult = onResult;
    lastOnError = onError;
  }

  @override
  Future<void> stopListening() async {
    stopListeningCallCount++;
    _isListening = false;
  }

  @override
  Future<void> cancelListening() async {
    cancelListeningCallCount++;
    _isListening = false;
    lastOnResult = null;
  }

  void simulateSpeech(String words, {bool isFinal = true}) {
    lastOnResult?.call(words, isFinal);
  }

  void simulateError(String error) {
    lastOnError?.call(error);
  }
}

/// Fake implementation of [SpeechOutputService] for unit testing.
class FakeSpeechOutputService implements SpeechOutputService {
  bool _isSpeaking = false;
  List<String> spokenTexts = [];
  List<String> spokenLanguages = [];
  int stopCallCount = 0;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<void> initialize({
    Function()? onStart,
    Function()? onDone,
    Function(String error)? onError,
  }) async {}

  @override
  Future<bool> isLanguageAvailable(String languageCode) async => true;

  @override
  Future<void> speak(
    String text, {
    required String languageCode,
    Function()? onDone,
  }) async {
    _isSpeaking = true;
    spokenTexts.add(text);
    spokenLanguages.add(languageCode);
    _isSpeaking = false;
    onDone?.call();
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    _isSpeaking = false;
  }
}

class FakeAssistantResponder implements AssistantResponder {
  final calls =
      <({String query, String languageCode, List<ChatMessage>? context})>[];

  @override
  Future<String> respond({
    required String query,
    required String languageCode,
    List<ChatMessage>? conversationContext,
  }) async {
    calls.add((
      query: query,
      languageCode: languageCode,
      context: conversationContext,
    ));
    return 'Test AI reply';
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ConversationRepository repository;
  late FakeSpeechRecognitionService fakeRecognition;
  late FakeSpeechOutputService fakeOutput;
  late AssistantResponder responder;
  late VoiceAssistantController controller;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async =>
            await db.execute('PRAGMA foreign_keys = ON;'),
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE conversations (
              id TEXT PRIMARY KEY,
              owner_id TEXT,
              title TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              last_opened_at INTEGER NOT NULL,
              is_archived INTEGER NOT NULL DEFAULT 0
            );
          ''');
          await db.execute('''
            CREATE TABLE messages (
              id TEXT PRIMARY KEY,
              conversation_id TEXT NOT NULL,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              screen_name TEXT,
              action_name TEXT,
              action_status TEXT,
              FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
          ''');
        },
      ),
    );

    repository = ConversationRepositoryImpl(
      dbHelper: ConversationDatabase.withDatabase(db),
    );
    fakeRecognition = FakeSpeechRecognitionService();
    fakeOutput = FakeSpeechOutputService();
    responder = FakeAssistantResponder();

    controller = VoiceAssistantController(
      conversationRepository: repository,
      speechRecognitionService: fakeRecognition,
      speechOutputService: fakeOutput,
      responder: responder,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('VoiceAssistantController & Speech Flow Tests', () {
    test(
      'Initialization restores last-opened conversation for current owner',
      () async {
        // Prepopulate conversation for owner 'farmer_1'
        final conv = await repository.createConversation(
          id: 'c_prior',
          ownerId: 'farmer_1',
          title: 'Prior Checkup',
        );
        await repository.addMessage(
          ChatMessage(
            id: 'm1',
            conversationId: conv.id,
            role: 'user',
            content: 'Check cow health',
            createdAt: 1000,
          ),
        );

        await controller.init(currentOwnerId: 'farmer_1');

        expect(controller.activeConversation, isNotNull);
        expect(controller.activeConversation!.id, equals('c_prior'));
        expect(controller.messages.length, equals(1));
        expect(controller.messages.first.content, equals('Check cow health'));
        expect(controller.previousConversations.length, equals(1));
      },
    );

    test(
      'Recognized text reaches fake AI responder and saves both messages',
      () async {
        await controller.init(currentOwnerId: 'vet_1');

        // Start listening in English
        await controller.startListening(languageCode: 'en');
        expect(controller.isListening, isTrue);
        expect(fakeRecognition.startListeningCallCount, equals(1));
        expect(fakeRecognition.lastStartedLanguage, equals('en'));

        // Simulate recognized words
        fakeRecognition.simulateSpeech('Hello Gau-Prahari', isFinal: true);
        // Wait for async processing to complete
        for (int i = 0; i < 50; i++) {
          if (controller.messages.length >= 2) break;
          await Future.delayed(const Duration(milliseconds: 15));
        }

        // Verify user message and assistant response
        expect(controller.messages.length, equals(2));
        expect(controller.messages[0].role, equals('user'));
        expect(controller.messages[0].content, equals('Hello Gau-Prahari'));

        expect(controller.messages[1].role, equals('assistant'));
        expect(controller.messages[1].content, equals('Test AI reply'));

        // Verify spoken aloud via TTS
        expect(fakeOutput.spokenTexts.length, equals(1));
        expect(fakeOutput.spokenTexts.first, equals('Test AI reply'));
        expect(fakeOutput.spokenLanguages.first, equals('en'));

        // Verify persisted in SQLite
        final dbMessages = await repository.getMessages(
          controller.activeConversation!.id,
        );
        expect(dbMessages.length, equals(2));
        expect(dbMessages[0].content, equals('Hello Gau-Prahari'));
        expect(dbMessages[1].content, equals('Test AI reply'));
      },
    );

    test(
      'Language selection operates in Hindi and Marathi correctly',
      () async {
        await controller.init(currentOwnerId: 'farmer_2');

        // Test Hindi interaction
        await controller.submitQuery(
          'गाय की स्थिति क्या है',
          languageCode: 'hi',
        );
        await pumpEventQueue();

        expect(controller.messages.length, equals(2));
        expect(controller.messages[1].content, equals('Test AI reply'));
        expect(fakeOutput.spokenLanguages.last, equals('hi'));

        // Start new conversation and test Marathi interaction
        await controller.startNewConversation();
        await controller.submitQuery(
          'गोठ्याची स्थिती दाखवा',
          languageCode: 'mr',
        );
        await pumpEventQueue();

        expect(controller.messages.length, equals(2));
        expect(controller.messages[1].content, equals('Test AI reply'));
        expect(fakeOutput.spokenLanguages.last, equals('mr'));
      },
    );

    test(
      'Repeated taps do not trigger overlapping listening or duplicate processing',
      () async {
        await controller.init(currentOwnerId: 'user_1');

        await controller.startListening(languageCode: 'en');
        expect(fakeRecognition.startListeningCallCount, equals(1));

        // Attempt second start while already listening - should be ignored
        await controller.startListening(languageCode: 'en');
        expect(fakeRecognition.startListeningCallCount, equals(1));
      },
    );

    test(
      'Microphone permission denial is handled gracefully without crashing',
      () async {
        fakeRecognition.hasPermissionResult = false;
        await controller.init(currentOwnerId: 'user_1');

        await controller.startListening(languageCode: 'en');

        expect(controller.status, equals(VoiceAssistantStatus.error));
        expect(controller.errorMessage, equals('permissionDenied'));
        expect(controller.messages, isEmpty);
      },
    );

    test('No speech detected sets friendly recoverable state', () async {
      await controller.init(currentOwnerId: 'user_1');
      await controller.startListening(languageCode: 'en');

      // Simulate empty speech final result
      fakeRecognition.simulateSpeech('', isFinal: true);
      for (int i = 0; i < 50; i++) {
        if (controller.status == VoiceAssistantStatus.idle) break;
        await Future.delayed(const Duration(milliseconds: 15));
      }

      expect(controller.status, equals(VoiceAssistantStatus.idle));
      expect(controller.errorMessage, equals('noSpeechDetected'));
      expect(controller.messages, isEmpty);
    });

    test('Starting a new conversation keeps older history available', () async {
      await controller.init(currentOwnerId: 'user_1');

      await controller.submitQuery('First query', languageCode: 'en');
      await pumpEventQueue();
      final firstConvId = controller.activeConversation!.id;

      // Start new conversation
      await controller.startNewConversation();
      expect(controller.activeConversation, isNull);
      expect(controller.messages, isEmpty);

      // Verify previous conversations list contains first conversation
      expect(
        controller.previousConversations.any((c) => c.id == firstConvId),
        isTrue,
      );

      // Submit message in new conversation
      await controller.submitQuery('Second query', languageCode: 'en');
      await pumpEventQueue();
      final secondConvId = controller.activeConversation!.id;
      expect(secondConvId, isNot(equals(firstConvId)));

      // Reopen first conversation
      await controller.openConversation(firstConvId);
      expect(controller.activeConversation!.id, equals(firstConvId));
      expect(controller.messages.first.content, equals('First query'));
    });
  });
}
