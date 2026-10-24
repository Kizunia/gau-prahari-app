import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
       _timeout = timeout {
    _log('service_initialized model=$modelId');
  }

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
    final hasApiKey = _apiKey.trim().isNotEmpty;
    _log('configuration_check api_key_configured=$hasApiKey');
    if (!hasApiKey) {
      return _fallback(languageCode, reason: 'missing_api_key');
    }

    // The controller supplies history after saving the current transcript.
    // Deduplicate defensively and retain only the latest 20 entries.
    final history = (conversationContext ?? <ChatMessage>[])
        .where((message) => message.content.trim().isNotEmpty)
        .toList();
    final receivedHistoryCount = history.length;
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
    final currentQueryIncludedOnce =
        recent.isNotEmpty &&
        recent.last.role == 'user' &&
        recent.last.content == query;
    _log(
      'conversation_prepared history_received=$receivedHistoryCount '
      'messages_sent=${recent.length} current_query_included_once=$currentQueryIncludedOnce',
    );

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
    _log(
      'request_constructed host=${uri.host} model=$modelId '
      'timeout_ms=${_timeout.inMilliseconds}',
    );
    final stopwatch = Stopwatch();
    try {
      stopwatch.start();
      _log('request_start');
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
      stopwatch.stop();
      _log(
        'request_completed http_status=${response.statusCode} '
        'elapsed_ms=${stopwatch.elapsedMilliseconds}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log(
          'http_failure http_status=${response.statusCode} '
          '${_apiErrorDiagnostic(response.body, privateValues: [query, ...recent.map((message) => message.content)])}',
        );
        return _fallback(languageCode, reason: 'http_error');
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
        _log('response_json_valid=true');
      } on FormatException catch (error) {
        _log(
          'response_json_valid=false exception_type=${error.runtimeType} '
          'body_length=${response.body.length}',
        );
        return _fallback(languageCode, reason: 'malformed_response');
      }
      if (decoded is! Map<String, dynamic>) {
        _log('response_json_valid=true response_shape=unexpected');
        return _fallback(languageCode, reason: 'malformed_response');
      }
      final candidates = decoded['candidates'];
      _log(
        'response_candidates_present=${candidates is List && candidates.isNotEmpty}',
      );
      if (candidates is! List ||
          candidates.isEmpty ||
          candidates.first is! Map) {
        _log('response_finish_reason=unavailable');
        return _fallback(languageCode, reason: 'malformed_response');
      }
      final candidate = candidates.first as Map;
      final content = candidate['content'];
      final parts = content is Map ? content['parts'] : null;
      _log(
        'response_text_parts_present=${parts is List && parts.any((part) => part is Map && part['text'] is String)} '
        'finish_reason=${_safeDiagnostic(candidate['finishReason'] ?? 'unavailable')}',
      );
      if (parts is! List) {
        return _fallback(languageCode, reason: 'malformed_response');
      }
      final reply = parts
          .whereType<Map>()
          .map((part) => part['text'])
          .whereType<String>()
          .join('\n')
          .trim();
      _log('response_reply_length=${reply.length}');
      if (reply.isEmpty) {
        return _fallback(languageCode, reason: 'empty_response');
      }
      _log('SUCCESS reply_length=${reply.length}');
      return reply;
    } on TimeoutException catch (error) {
      stopwatch.stop();
      _log(
        'timeout exception_type=${error.runtimeType} '
        'timeout_ms=${_timeout.inMilliseconds} '
        'elapsed_ms=${stopwatch.elapsedMilliseconds}',
      );
      return _fallback(languageCode, reason: 'timeout');
    } on http.ClientException catch (error) {
      stopwatch.stop();
      _log(
        'network_failure exception_type=${error.runtimeType} '
        'elapsed_ms=${stopwatch.elapsedMilliseconds} '
        'details="${_safeDiagnostic(error.message, privateValues: [query, ...recent.map((message) => message.content)])}"',
      );
      return _fallback(languageCode, reason: 'network_error');
    } on SocketException catch (error) {
      stopwatch.stop();
      _log(
        'network_failure exception_type=${error.runtimeType} '
        'elapsed_ms=${stopwatch.elapsedMilliseconds} '
        'details="${_safeDiagnostic(error.message, privateValues: [query, ...recent.map((message) => message.content)])}"',
      );
      return _fallback(languageCode, reason: 'network_error');
    } catch (error) {
      stopwatch.stop();
      _log(
        'unexpected_exception exception_type=${error.runtimeType} '
        'elapsed_ms=${stopwatch.elapsedMilliseconds} '
        'diagnostic=stack_trace_available',
      );
      if (kDebugMode) {
        debugPrintStack(label: '[Gemini] unexpected_exception_stack');
      }
      return _fallback(languageCode, reason: 'unexpected_error');
    }
  }

  String _apiErrorDiagnostic(
    String body, {
    required Iterable<String> privateValues,
  }) {
    try {
      final decoded = jsonDecode(body);
      final error = decoded is Map ? decoded['error'] : null;
      if (error is Map) {
        final code = error['code'] ?? 'unavailable';
        final status = error['status'] ?? 'unavailable';
        final message = error['message'] ?? 'No API error message provided';
        return 'api_error_code=${_safeDiagnostic(code, privateValues: privateValues)} '
            'api_error_status=${_safeDiagnostic(status, privateValues: privateValues)} '
            'api_error_message="${_safeDiagnostic(message, privateValues: privateValues)}"';
      }
      return 'api_error_body=unrecognized_json body_length=${body.length}';
    } on FormatException catch (error) {
      return 'api_error_body=invalid_json body_length=${body.length} '
          'exception_type=${error.runtimeType}';
    }
  }

  String _safeDiagnostic(
    Object? value, {
    Iterable<String> privateValues = const [],
  }) {
    var text = value.toString();
    if (_apiKey.isNotEmpty) text = text.replaceAll(_apiKey, '[REDACTED]');
    for (final privateValue in privateValues) {
      if (privateValue.isNotEmpty) {
        text = text.replaceAll(privateValue, '[REDACTED]');
      }
    }
    text = text.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    if (text.length > 240) text = '${text.substring(0, 240)}…';
    return text;
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[Gemini] $message');
  }

  String _fallback(String languageCode, {required String reason}) {
    _log('FALLBACK reason=$reason');
    return switch (languageCode) {
      'hi' =>
        'अभी AI सहायक से जवाब नहीं मिल सका। आपका सवाल इस बातचीत में सुरक्षित है। कृपया इंटरनेट या API सेटिंग जाँचकर फिर कोशिश करें।',
      'mr' =>
        'आत्ता AI सहाय्यकाकडून उत्तर मिळू शकले नाही. तुमचा प्रश्न या संभाषणात जतन केला आहे. कृपया इंटरनेट किंवा API सेटिंग तपासून पुन्हा प्रयत्न करा.',
      _ =>
        'I could not get a reply from the AI assistant just now. Your question is saved in this conversation. Please check your internet connection or API settings and try again.',
    };
  }
}
