import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/ai_config.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/services/assistant_responder.dart';

/// Gemini REST implementation of the Phase II text-only assistant.
class AiAssistantService implements AssistantResponder {
  static const modelId = 'gemini-3.8-flash';
  static const _defaultTimeout = Duration(seconds: 25);
  final http.Client _client;
  final String _apiKey;
  final Duration _timeout;

  AiAssistantService({
    http.Client? client,
    String? apiKey,
    Duration timeout = _defaultTimeout,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey ?? geminiApiKey,
       _timeout = timeout;

  @override
  Future<String> respond({
    required String query,
    required String languageCode,
    List<ChatMessage>? conversationContext,
  }) async {
    final lang = switch (languageCode) {
      'hi' => 'Hindi',
      'mr' => 'Marathi',
      _ => 'English',
    };
    if (_apiKey.trim().isEmpty) return _fallback(languageCode);

    // The controller supplies history after saving the current transcript.
    // Deduplicate defensively and retain only the latest 20 entries.
    final history = (conversationContext ?? <ChatMessage>[])
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    if (history.isEmpty ||
        history.last.role != 'user' ||
        history.last.content != query) {
      history.add(
        ChatMessage(
          id: 'current',
          conversationId: '',
          role: 'user',
          content: query,
          createdAt: 0,
        ),
      );
    }
    final recent = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    final contents = recent
        .map(
          (message) => {
            'role': message.role == 'assistant' ? 'model' : 'user',
            'parts': [
              {'text': message.content},
            ],
          },
        )
        .toList();

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$modelId:generateContent',
    );
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {
                    'text':
                        'You are Gau-Prahari, a helpful assistant for farmers. Reply concisely in $lang. Give simple natural-language guidance only. Do not claim to control the app or perform actions. If unsure, say so.',
                  },
                ],
              },
              'contents': contents,
              'generationConfig': {'maxOutputTokens': 512},
            }),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Gemini request failed with HTTP ${response.statusCode}.');
        return _fallback(languageCode);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return _fallback(languageCode);
      final candidates = decoded['candidates'];
      if (candidates is! List ||
          candidates.isEmpty ||
          candidates.first is! Map) {
        return _fallback(languageCode);
      }
      final content = (candidates.first as Map)['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List) return _fallback(languageCode);
      final reply = parts
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join('\n')
          .trim();
      return reply.isEmpty ? _fallback(languageCode) : reply;
    } on TimeoutException {
      return _fallback(languageCode);
    } on http.ClientException {
      return _fallback(languageCode);
    } on FormatException {
      return _fallback(languageCode);
    } catch (error) {
      debugPrint('Gemini response could not be processed: $error');
      return _fallback(languageCode);
    }
  }

  static String _fallback(String languageCode) => switch (languageCode) {
    'hi' =>
      'अभी AI सहायक से जवाब नहीं मिल सका। आपका सवाल इस बातचीत में सुरक्षित है। कृपया इंटरनेट या API सेटिंग जाँचकर फिर कोशिश करें।',
    'mr' =>
      'आत्ता AI सहाय्यकाकडून उत्तर मिळू शकले नाही. तुमचा प्रश्न या संभाषणात जतन केला आहे. कृपया इंटरनेट किंवा API सेटिंग तपासून पुन्हा प्रयत्न करा.',
    _ =>
      'I could not get a reply from the AI assistant just now. Your question is saved in this conversation. Please check your internet connection or API settings and try again.',
  };
}
