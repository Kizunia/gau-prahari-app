import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gau_prahari/features/voice_assistant/data/services/ai_assistant_service.dart';
import 'package:gau_prahari/features/voice_assistant/domain/entities/chat_message.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends the latest 20 messages once and parses Gemini text', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      expect(
        request.url.path,
        contains('/v1beta/models/gemini-3.8-flash:generateContent'),
      );
      expect(request.headers['x-goog-api-key'], 'test-key');
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Gemini answer'},
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final service = AiAssistantService(client: client, apiKey: 'test-key');
    final history = List.generate(
      24,
      (i) => ChatMessage(
        id: 'm$i',
        conversationId: 'active',
        role: i == 23 || i.isEven ? 'user' : 'assistant',
        content: i == 23 ? 'Current question' : 'Message $i',
        createdAt: i,
      ),
    );

    expect(
      await service.respond(
        query: 'Current question',
        languageCode: 'hi',
        conversationContext: history,
      ),
      'Gemini answer',
    );
    final contents = requestBody['contents'] as List;
    expect(contents, hasLength(20));
    expect(
      contents.where(
        (entry) => entry['parts'][0]['text'] == 'Current question',
      ),
      hasLength(1),
    );
    expect(
      requestBody['systemInstruction']['parts'][0]['text'],
      contains('Hindi'),
    );
  });

  test(
    'missing API key returns a useful language-aware fallback without network',
    () async {
      final service = AiAssistantService(
        client: MockClient(
          (_) async => throw StateError('must not call network'),
        ),
        apiKey: '',
      );

      final reply = await service.respond(query: 'नमस्ते', languageCode: 'hi');
      expect(reply, contains('AI सहायक'));
    },
  );

  test('HTTP failure returns a recoverable fallback', () async {
    final service = AiAssistantService(
      client: MockClient((_) async => http.Response('quota exceeded', 429)),
      apiKey: 'test-key',
    );

    final reply = await service.respond(query: 'Help', languageCode: 'en');
    expect(reply, contains('Your question is saved'));
  });

  test(
    'malformed response and timeout return a recoverable fallback',
    () async {
      final malformed = AiAssistantService(
        client: MockClient((_) async => http.Response('{bad json', 200)),
        apiKey: 'test-key',
      );
      expect(
        await malformed.respond(query: 'Help', languageCode: 'mr'),
        contains('तुमचा प्रश्न'),
      );

      final timeout = AiAssistantService(
        client: MockClient((_) => Completer<http.Response>().future),
        apiKey: 'test-key',
        timeout: const Duration(milliseconds: 1),
      );
      expect(
        await timeout.respond(query: 'Help', languageCode: 'en'),
        contains('Your question is saved'),
      );
    },
  );
}
