import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:gau_prahari/features/voice_assistant/data/services/ai_assistant_service.dart';
import 'package:gau_prahari/features/voice_assistant/domain/entities/chat_message.dart';

class FakeGeminiSdkClient implements GeminiSdkClient {
  FakeGeminiSdkClient(this.results);

  final List<FutureOr<Object?>> results;
  final models = <String>[];
  final messages = <String>[];
  final histories = <List<Content>>[];
  final systemInstructions = <String>[];

  @override
  Future<String?> sendMessage({
    required String model,
    required String apiKey,
    required String systemInstruction,
    required List<Content> history,
    required String message,
    required Duration timeout,
  }) async {
    models.add(model);
    messages.add(message);
    histories.add(history);
    systemInstructions.add(systemInstruction);
    final result = await results.removeAt(0);
    if (result is Exception) throw result;
    return result as String?;
  }
}

Future<List<ConnectivityResult>> connected() async => [ConnectivityResult.wifi];

ChatMessage message(
  String role,
  String content, {
  String conversationId = 'a',
}) => ChatMessage(
  id: '$role-$content',
  conversationId: conversationId,
  role: role,
  content: content,
  createdAt: 1,
);

void main() {
  test('attempts supported models sequentially and stops at the bound', () async {
    final sdk = FakeGeminiSdkClient([
      GenerativeAIException(
        'Server Error [503]: {"error":{"code":503,"status":"UNAVAILABLE","message":"temporarily overloaded"}}',
      ),
      GenerativeAIException(
        'Server Error [503]: {"error":{"code":503,"status":"UNAVAILABLE","message":"temporarily overloaded"}}',
      ),
      GenerativeAIException(
        'Server Error [503]: {"error":{"code":503,"status":"UNAVAILABLE","message":"temporarily overloaded"}}',
      ),
    ]);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
    );

    final reply = await service.respond(query: 'Help', languageCode: 'en');

    expect(sdk.models, AiAssistantService.modelIds);
    expect(sdk.models, hasLength(3));
    expect(reply, contains('Your question is saved'));
  });

  test('a successful model prevents later fallback attempts', () async {
    final sdk = FakeGeminiSdkClient(['Gemini answer', 'Unused fallback']);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
    );

    expect(
      await service.respond(query: 'Help', languageCode: 'en'),
      'Gemini answer',
    );
    expect(sdk.models, [AiAssistantService.modelIds.first]);
  });

  test('failure on one model continues to the next model', () async {
    final sdk = FakeGeminiSdkClient([
      GenerativeAIException(
        'Server Error [503]: {"error":{"code":503,"status":"UNAVAILABLE","message":"temporary demand"}}',
      ),
      'Recovered answer',
      'Unused fallback',
    ]);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
    );

    expect(
      await service.respond(query: 'Help', languageCode: 'en'),
      'Recovered answer',
    );
    expect(sdk.models, AiAssistantService.modelIds.take(2));
  });

  test('empty SDK response is not treated as success', () async {
    final sdk = FakeGeminiSdkClient(['  ', 'Fallback model answer']);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
    );

    expect(
      await service.respond(query: 'Help', languageCode: 'en'),
      'Fallback model answer',
    );
    expect(sdk.models, AiAssistantService.modelIds.take(2));
  });

  test('offline connectivity skips all model attempts', () async {
    final sdk = FakeGeminiSdkClient([]);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: () async => [ConnectivityResult.none],
    );

    final reply = await service.respond(query: 'Help', languageCode: 'mr');

    expect(sdk.models, isEmpty);
    expect(reply, contains('तुमचा प्रश्न'));
  });

  test(
    'selected language and active conversation history are preserved',
    () async {
      final sdk = FakeGeminiSdkClient(['उत्तर']);
      final service = AiAssistantService(
        apiKey: 'test-key',
        sdkClient: sdk,
        connectivityCheck: connected,
      );
      final history = [
        message('user', 'मागचा प्रश्न'),
        message('assistant', 'मागचे उत्तर'),
        message('user', 'सध्याचा प्रश्न'),
      ];

      await service.respond(
        query: 'सध्याचा प्रश्न',
        languageCode: 'mr',
        conversationContext: history,
      );

      expect(sdk.systemInstructions.single, contains('Marathi'));
      expect(sdk.messages.single, 'सध्याचा प्रश्न');
      expect(sdk.histories.single, hasLength(2));
      expect(sdk.histories.single[0].role, 'user');
      expect(sdk.histories.single[1].role, 'model');
      expect(
        (sdk.histories.single[1].parts.single as TextPart).text,
        'मागचे उत्तर',
      );
    },
  );

  test(
    'current question is sent once when it is present in saved history',
    () async {
      final sdk = FakeGeminiSdkClient(['Answer']);
      final service = AiAssistantService(
        apiKey: 'test-key',
        sdkClient: sdk,
        connectivityCheck: connected,
      );

      await service.respond(
        query: 'Current question',
        languageCode: 'en',
        conversationContext: [
          message('assistant', 'Previous reply'),
          message('user', 'Current question'),
        ],
      );

      expect(sdk.messages, ['Current question']);
      expect(sdk.histories.single, hasLength(1));
      expect(sdk.histories.single.single.role, 'model');
    },
  );

  test('history is capped at twenty including the current question', () async {
    final sdk = FakeGeminiSdkClient(['Answer']);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
    );
    final history = List.generate(
      24,
      (index) => message(index.isEven ? 'user' : 'assistant', 'History $index'),
    );

    await service.respond(
      query: 'Current question',
      languageCode: 'en',
      conversationContext: history,
    );

    expect(sdk.histories.single, hasLength(19));
    expect(
      (sdk.histories.single.first.parts.single as TextPart).text,
      'History 5',
    );
    expect(sdk.messages.single, 'Current question');
  });

  test('history from another conversation is excluded', () async {
    final sdk = FakeGeminiSdkClient(['Answer']);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
    );

    await service.respond(
      query: 'Current question',
      languageCode: 'en',
      conversationContext: [
        message('user', 'Other conversation', conversationId: 'other'),
        message('assistant', 'Relevant context', conversationId: 'active'),
        message('user', 'Current question', conversationId: 'active'),
      ],
    );

    expect(sdk.histories.single, hasLength(1));
    expect(
      (sdk.histories.single.single.parts.single as TextPart).text,
      'Relevant context',
    );
  });

  test('timeout advances sequentially and returns without hanging', () async {
    final neverCompletes = Completer<Object?>();
    final sdk = FakeGeminiSdkClient([
      neverCompletes.future,
      'Answer after timeout',
      'Unused fallback',
    ]);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
      attemptTimeout: const Duration(milliseconds: 20),
      overallTimeout: const Duration(milliseconds: 200),
    );

    expect(
      await service
          .respond(query: 'Help', languageCode: 'en')
          .timeout(const Duration(seconds: 2)),
      'Answer after timeout',
    );
    expect(sdk.models, AiAssistantService.modelIds.take(2));
  });

  test(
    'authentication failure is terminal and localized fallback is kept',
    () async {
      final sdk = FakeGeminiSdkClient([InvalidApiKey('invalid key'), 'unused']);
      final service = AiAssistantService(
        apiKey: 'test-key',
        sdkClient: sdk,
        connectivityCheck: connected,
      );

      expect(
        await service.respond(query: 'मदत', languageCode: 'mr'),
        contains('तुमचा प्रश्न'),
      );
      expect(sdk.models, [AiAssistantService.modelIds.first]);
    },
  );

  test('model-specific access error continues to the next model', () async {
    final sdk = FakeGeminiSdkClient([
      ServerException('403 permission denied for model gemini-2.5-flash'),
      'Answer from next model',
    ]);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
    );

    expect(
      await service.respond(query: 'Help', languageCode: 'en'),
      'Answer from next model',
    );
    expect(sdk.models, AiAssistantService.modelIds.take(2));
  });

  test('daily quota error does not retry other models blindly', () async {
    final sdk = FakeGeminiSdkClient([
      ServerException('429 RESOURCE_EXHAUSTED: daily quota exceeded'),
      'Unused fallback',
    ]);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
    );

    expect(
      await service.respond(query: 'Help', languageCode: 'en'),
      contains('Your question is saved'),
    );
    expect(sdk.models, [AiAssistantService.modelIds.first]);
  });

  test('missing API key returns localized fallback without SDK call', () async {
    final sdk = FakeGeminiSdkClient([]);
    final service = AiAssistantService(
      apiKey: '',
      sdkClient: sdk,
      connectivityCheck: connected,
    );

    expect(
      await service.respond(query: 'नमस्ते', languageCode: 'hi'),
      contains('AI सहायक'),
    );
    expect(sdk.models, isEmpty);
  });

  test('concurrent interactions do not make parallel SDK calls', () async {
    final pending = Completer<Object?>();
    final sdk = FakeGeminiSdkClient([pending.future]);
    final service = AiAssistantService(
      apiKey: 'test-key',
      sdkClient: sdk,
      connectivityCheck: connected,
    );

    final first = service.respond(
      query: 'First',
      languageCode: 'en',
      requestId: 'request-1',
    );
    await Future<void>.delayed(Duration.zero);
    final second = await service.respond(
      query: 'Second',
      languageCode: 'en',
      requestId: 'request-2',
    );

    expect(second, contains('Your question is saved'));
    expect(sdk.models, [AiAssistantService.modelIds.first]);
    pending.complete('First answer');
    expect(await first, 'First answer');
  });
}
