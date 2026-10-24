import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gau_prahari/features/voice_assistant/data/services/ai_assistant_service.dart';
import 'package:gau_prahari/features/voice_assistant/domain/entities/chat_message.dart';

class FakeHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  final List<http.Request> recordedRequests = [];

  FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    recordedRequests.add(httpRequest);
    final res = await handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await AiAssistantService.setApiKey(null);
  });

  group('AiAssistantService Tests', () {
    test('Returns missing key prompt if no API key is configured', () async {
      final service = AiAssistantService(apiKey: '');

      final enReply = await service.respond(
        query: 'How to check cow health?',
        languageCode: 'en',
      );
      expect(enReply, contains('Please configure your Gemini API Key'));

      final hiReply = await service.respond(
        query: 'गाय का स्वास्थ्य कैसे जांचें?',
        languageCode: 'hi',
      );
      expect(hiReply, contains('Gemini API कुंजी कॉन्फ़िगर करें'));

      final mrReply = await service.respond(
        query: 'गायीचे आरोग्य कसे तपासायचे?',
        languageCode: 'mr',
      );
      expect(mrReply, contains('Gemini API की कॉन्फिगर करा'));
    });

    test('Parses successful Gemini 200 JSON response properly', () async {
      await AiAssistantService.setApiKey('test_fake_api_key_123');

      final fakeClient = FakeHttpClient((req) async {
        expect(req.url.queryParameters['key'], 'test_fake_api_key_123');
        expect(req.headers['x-goog-api-key'], 'test_fake_api_key_123');

        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body.containsKey('contents'), isTrue);
        expect(body.containsKey('systemInstruction'), isTrue);

        final geminiResponse = {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {
                    'text':
                        'Cow 104 has normal skin temperature and stable THI index.',
                  },
                ],
              },
              'finishReason': 'STOP',
            },
          ],
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(geminiResponse)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = AiAssistantService(httpClient: fakeClient);
      final reply = await service.respond(
        query: 'What is the status of cow 104?',
        languageCode: 'en',
      );

      expect(
        reply,
        'Cow 104 has normal skin temperature and stable THI index.',
      );
      expect(fakeClient.recordedRequests.length, 1);
    });

    test('Formats multi-turn conversation context correctly for Gemini API', () async {
      await AiAssistantService.setApiKey('test_fake_api_key_123');

      late Map<String, dynamic> sentPayload;
      final fakeClient = FakeHttpClient((req) async {
        sentPayload = jsonDecode(req.body) as Map<String, dynamic>;
        final geminiResponse = {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {
                    'text':
                        'Subclinical mastitis risk can be reduced with proper teat dipping.',
                  },
                ],
              },
            },
          ],
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(geminiResponse)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = AiAssistantService(httpClient: fakeClient);
      final history = [
        const ChatMessage(
          id: '1',
          conversationId: 'c1',
          role: 'user',
          content: 'Hello doctor',
          createdAt: 1000,
        ),
        const ChatMessage(
          id: '2',
          conversationId: 'c1',
          role: 'assistant',
          content: 'Hello, how is your herd today?',
          createdAt: 2000,
        ),
      ];

      final reply = await service.respond(
        query: 'How to reduce mastitis risk?',
        languageCode: 'en',
        conversationContext: history,
      );

      expect(reply, contains('Subclinical mastitis risk'));
      final contents = sentPayload['contents'] as List<dynamic>;
      expect(contents.length, 3);
      expect(contents[0]['role'], 'user');
      expect(contents[1]['role'], 'model');
      expect(contents[2]['role'], 'user');
    });

    test('Includes screen context in system instruction', () async {
      await AiAssistantService.setApiKey('test_fake_api_key_123');

      late Map<String, dynamic> sentPayload;
      final fakeClient = FakeHttpClient((req) async {
        sentPayload = jsonDecode(req.body) as Map<String, dynamic>;
        final geminiResponse = {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {
                    'text':
                        'You are on the analysis result screen for cow COW-104 with moderate risk.',
                  },
                ],
              },
            },
          ],
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(geminiResponse)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = AiAssistantService(httpClient: fakeClient);
      await service.respond(
        query: 'Explain this screen',
        languageCode: 'en',
        screenContext: {
          'screenName': 'analysis_result',
          'cowId': 'COW-104',
          'riskLevel': 'MODERATE',
        },
      );

      final sysInstruction =
          sentPayload['systemInstruction']['parts'][0]['text'] as String;
      expect(sysInstruction, contains('CURRENT APPLICATION SCREEN CONTEXT'));
      expect(sysInstruction, contains('COW-104'));
      expect(sysInstruction, contains('MODERATE'));
    });

    test('Instructs model to provide general purpose cattle disease and farming answers uncoupled from app pitch', () async {
      await AiAssistantService.setApiKey('test_fake_api_key_123');

      late Map<String, dynamic> sentPayload;
      final fakeClient = FakeHttpClient((req) async {
        sentPayload = jsonDecode(req.body) as Map<String, dynamic>;
        final geminiResponse = {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {
                    'text':
                        'गायींमध्ये लाळ-खुरकूत, लंपी त्वचा रोग, आणि स्तनदाह हे प्रमुख आजार आढळतात.',
                  },
                ],
              },
            },
          ],
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(geminiResponse)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = AiAssistantService(httpClient: fakeClient);
      final reply = await service.respond(
        query: 'मला गाईच्या आजाराबद्दल माहिती हवी आहे',
        languageCode: 'mr',
      );

      expect(reply, contains('गायींमध्ये'));
      final sysInstruction =
          sentPayload['systemInstruction']['parts'][0]['text'] as String;
      expect(sysInstruction, contains('FULL GENERAL-PURPOSE KNOWLEDGE'));
      expect(
        sysInstruction,
        contains('NOT limited or tightly coupled only to the Gau-Prahari app'),
      );
      expect(sysInstruction, contains('Cattle Health & Diseases'));
      final generationConfig =
          sentPayload['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['maxOutputTokens'], 1024);
      expect(generationConfig['thinkingConfig']['thinkingLevel'], 'low');
    });

    test('Retries with fallback model when primary model returns 404', () async {
      await AiAssistantService.setApiKey('test_fake_api_key_123');

      int callCount = 0;
      final fakeClient = FakeHttpClient((req) async {
        callCount++;
        if (callCount == 1) {
          // Primary model not found
          return http.Response('{"error": {"code": 404, "message": "Model not found"}}', 404);
        } else {
          // Fallback model succeeds
          final geminiResponse = {
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'Fallback model response.'},
                  ],
                },
              },
            ],
          };
          return http.Response.bytes(
          utf8.encode(jsonEncode(geminiResponse)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
        }
      });

      final service = AiAssistantService(httpClient: fakeClient);
      final reply = await service.respond(
        query: 'Status check',
        languageCode: 'en',
      );

      expect(reply, 'Fallback model response.');
      expect(callCount, 2);
    });

    test('Handles 429 quota rate limit cleanly without crashing', () async {
      await AiAssistantService.setApiKey('test_fake_api_key_123');

      final fakeClient = FakeHttpClient((req) async {
        return http.Response(
          '{"error": {"code": 429, "message": "Resource exhausted"}}',
          429,
        );
      });

      final service = AiAssistantService(httpClient: fakeClient);
      final reply = await service.respond(
        query: 'Check cow',
        languageCode: 'en',
      );

      expect(reply, contains('rate limit reached'));
    });

    test('Handles invalid 401/403 API keys gracefully', () async {
      await AiAssistantService.setApiKey('test_fake_api_key_123');

      final fakeClient = FakeHttpClient((req) async {
        return http.Response(
          '{"error": {"code": 403, "message": "Permission denied"}}',
          403,
        );
      });

      final service = AiAssistantService(httpClient: fakeClient);
      final reply = await service.respond(
        query: 'Check cow',
        languageCode: 'en',
      );

      expect(reply, contains('Invalid or unauthorized Gemini API key'));
    });

    test('Handles SocketException network error gracefully', () async {
      await AiAssistantService.setApiKey('test_fake_api_key_123');

      final fakeClient = FakeHttpClient((req) async {
        throw const SocketException('Failed host lookup: generativelanguage.googleapis.com');
      });

      final service = AiAssistantService(httpClient: fakeClient);
      final reply = await service.respond(
        query: 'Check cow',
        languageCode: 'en',
      );

      expect(reply, contains('Network connection error'));
    });

    test('Handles TimeoutException gracefully', () async {
      await AiAssistantService.setApiKey('test_fake_api_key_123');

      final fakeClient = FakeHttpClient((req) async {
        throw TimeoutException('Request timed out');
      });

      final service = AiAssistantService(httpClient: fakeClient);
      final reply = await service.respond(
        query: 'Check cow',
        languageCode: 'en',
      );

      expect(reply, contains('took too long to respond'));
    });

    test('sanitizeApiKey strips quotes, semicolons, prefixes, placeholders, and whitespace', () {
      expect(
        AiAssistantService.sanitizeApiKey('  "MOCK_GEMINI_KEY_1234567890_abcdefghij"  '),
        'MOCK_GEMINI_KEY_1234567890_abcdefghij',
      );
      expect(
        AiAssistantService.sanitizeApiKey("geminiApiKey = 'MOCK_GEMINI_KEY_1234567890_abcdefghij';"),
        'MOCK_GEMINI_KEY_1234567890_abcdefghij',
      );
      expect(
        AiAssistantService.sanitizeApiKey('YOUR_GEMINI_API_KEY_HEREMOCK_GEMINI_KEY_1234567890_abcdefghij'),
        'MOCK_GEMINI_KEY_1234567890_abcdefghij',
      );
    });
  });
}
