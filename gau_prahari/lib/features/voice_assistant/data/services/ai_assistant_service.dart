import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/ai_config.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/services/assistant_responder.dart';

/// Narrow seam around the Google SDK so service behavior can be tested without
/// a real API key or network request.
abstract interface class GeminiSdkClient {
  Future<String?> sendMessage({
    required String model,
    required String apiKey,
    required String systemInstruction,
    required List<Content> history,
    required String message,
    required Duration timeout,
  });
}

typedef ConnectivityCheck = Future<List<ConnectivityResult>> Function();

/// Gemini implementation of the Phase II text-only assistant.
class AiAssistantService implements AssistantResponder {
  static int _globalRequestSequence = 0;
  static const modelIds = [
    'gemini-2.5-flash',
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
  ];
  static const _attemptTimeout = Duration(seconds: 15);
  static const _connectivityTimeout = Duration(seconds: 2);
  static const _overallTimeout = Duration(seconds: 40);
  static const _transientRetryBaseDelay = Duration(milliseconds: 300);

  final String _apiKey;
  final GeminiSdkClient _sdkClient;
  final ConnectivityCheck _checkConnectivity;
  final Duration _modelAttemptTimeout;
  final Duration _networkCheckTimeout;
  final Duration _requestBudget;
  bool _requestInFlight = false;

  AiAssistantService({
    String? apiKey,
    GeminiSdkClient? sdkClient,
    ConnectivityCheck? connectivityCheck,
    Duration attemptTimeout = _attemptTimeout,
    Duration connectivityTimeout = _connectivityTimeout,
    Duration overallTimeout = _overallTimeout,
  }) : _apiKey = apiKey ?? geminiApiKey,
       _sdkClient = sdkClient ?? const _GoogleGeminiSdkClient(),
       _checkConnectivity =
           connectivityCheck ?? Connectivity().checkConnectivity,
       _modelAttemptTimeout = attemptTimeout,
       _networkCheckTimeout = connectivityTimeout,
       _requestBudget = overallTimeout {
    _log('service-init', 'service_initialized models=${modelIds.join(',')}');
  }

  @override
  Future<String> respond({
    required String query,
    required String languageCode,
    List<ChatMessage>? conversationContext,
    String? requestId,
  }) async {
    final id = requestId ?? _newRequestId();
    _log(id, 'request_received');
    if (_apiKey.trim().isEmpty) {
      _log(id, 'configuration_check api_key_configured=false');
      return _fallback(languageCode, id, 'missing_api_key');
    }
    _log(id, 'configuration_check api_key_configured=true');
    if (_requestInFlight) {
      return _fallback(languageCode, id, 'request_already_in_flight');
    }

    _requestInFlight = true;
    try {
      return await _respond(
        query: query,
        languageCode: languageCode,
        conversationContext: conversationContext,
        requestId: id,
      );
    } finally {
      _requestInFlight = false;
    }
  }

  Future<String> _respond({
    required String query,
    required String languageCode,
    required String requestId,
    List<ChatMessage>? conversationContext,
  }) async {
    final overallStopwatch = Stopwatch()..start();
    final languageName = switch (languageCode) {
      'hi' => 'Hindi',
      'mr' => 'Marathi',
      _ => 'English',
    };

    try {
      final connectivity = await _checkConnectivity().timeout(
        _networkCheckTimeout,
      );
      final offline =
          connectivity.isEmpty ||
          connectivity.every((result) => result == ConnectivityResult.none);
      _log(requestId, 'connectivity_checked network_available=${!offline}');
      if (offline) {
        return _fallback(languageCode, requestId, 'offline');
      }
    } on TimeoutException {
      _log(requestId, 'connectivity_check_timeout proceeding_to_sdk_request');
    } catch (error) {
      _log(
        requestId,
        'connectivity_check_failed exception_type=${error.runtimeType} '
        'proceeding_to_sdk_request',
      );
    }

    final suppliedHistory = conversationContext ?? const <ChatMessage>[];
    final activeConversationId = suppliedHistory.isEmpty
        ? null
        : suppliedHistory.last.conversationId;
    final history = suppliedHistory
        .where((message) => message.content.trim().isNotEmpty)
        .where(
          (message) =>
              activeConversationId == null ||
              message.conversationId == activeConversationId,
        )
        .toList();
    final receivedHistoryCount = history.length;
    final recent = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    // The controller includes the just-persisted user question in this context.
    // Remove it from chat history because it is sent separately exactly once.
    final previousTurns = List<ChatMessage>.of(recent);
    if (previousTurns.isNotEmpty &&
        previousTurns.last.role == 'user' &&
        previousTurns.last.content == query) {
      previousTurns.removeLast();
    } else if (previousTurns.length > 19) {
      previousTurns.removeRange(0, previousTurns.length - 19);
    }
    final currentQueryIncludedOnce = query.trim().isNotEmpty;
    final sdkHistory = previousTurns
        .map(
          (message) => message.role == 'assistant'
              ? Content.model([TextPart(message.content)])
              : Content.text(message.content),
        )
        .toList(growable: false);
    _log(
      requestId,
      'conversation_prepared history_received=$receivedHistoryCount '
      'messages_sent=${sdkHistory.length + (currentQueryIncludedOnce ? 1 : 0)} '
      'history_messages=${sdkHistory.length} '
      'current_query_included_once=$currentQueryIncludedOnce',
    );

    final systemInstruction =
        'You are Gau-Prahari, a helpful assistant for farmers. '
        'Reply concisely in $languageName. Give simple natural-language '
        'guidance only. Do not claim to control the app or perform actions. '
        'If unsure, say so.';
    final privateValues = <String>[
      query,
      ...history.map((message) => message.content),
    ];
    String lastReason = 'all_models_failed';

    for (var index = 0; index < modelIds.length; index++) {
      final remaining = _requestBudget - overallStopwatch.elapsed;
      if (remaining <= Duration.zero) {
        return _fallback(languageCode, requestId, 'overall_timeout');
      }
      final modelId = modelIds[index];
      final timeout = remaining < _modelAttemptTimeout
          ? remaining
          : _modelAttemptTimeout;
      final attemptStopwatch = Stopwatch()..start();
      final startedAt = DateTime.now().toUtc().toIso8601String();
      _log(
        requestId,
        'model_attempt_start attempt=${index + 1}/${modelIds.length} '
        'model=$modelId started_at=$startedAt timeout_ms=${timeout.inMilliseconds}',
      );

      try {
        final reply = await _sdkClient
            .sendMessage(
              model: modelId,
              apiKey: _apiKey,
              systemInstruction: systemInstruction,
              history: sdkHistory,
              message: query,
              timeout: timeout,
            )
            .timeout(timeout);
        attemptStopwatch.stop();
        final cleanReply = reply?.trim() ?? '';
        _log(
          requestId,
          'model_attempt_completed attempt=${index + 1}/${modelIds.length} '
          'model=$modelId elapsed_ms=${attemptStopwatch.elapsedMilliseconds} '
          'usable_response=${cleanReply.isNotEmpty}',
        );
        if (cleanReply.isNotEmpty) {
          _log(
            requestId,
            'SUCCESS model=$modelId reply_length=${cleanReply.length}',
          );
          return cleanReply;
        }
        lastReason = 'empty_response';
        _log(
          requestId,
          'model_attempt_failed model=$modelId category=empty_response',
        );
      } on TimeoutException catch (error) {
        attemptStopwatch.stop();
        lastReason = 'timeout';
        _logFailure(
          requestId,
          modelId,
          index,
          attemptStopwatch.elapsed,
          error,
          'timeout',
        );
      } on InvalidApiKey catch (error) {
        attemptStopwatch.stop();
        lastReason = 'authentication';
        _logFailure(
          requestId,
          modelId,
          index,
          attemptStopwatch.elapsed,
          error,
          lastReason,
          privateValues: privateValues,
        );
        return _fallback(languageCode, requestId, lastReason);
      } on UnsupportedUserLocation catch (error) {
        attemptStopwatch.stop();
        lastReason = 'project_or_location_access';
        _logFailure(
          requestId,
          modelId,
          index,
          attemptStopwatch.elapsed,
          error,
          lastReason,
          privateValues: privateValues,
        );
        return _fallback(languageCode, requestId, lastReason);
      } on ServerException catch (error) {
        attemptStopwatch.stop();
        lastReason = _classifyServerMessage(error.message, modelId: modelId);
        _logFailure(
          requestId,
          modelId,
          index,
          attemptStopwatch.elapsed,
          error,
          lastReason,
          privateValues: privateValues,
        );
        if (!_shouldContinueForServerFailure(lastReason, error.message)) {
          return _fallback(languageCode, requestId, lastReason);
        }
      } on SocketException catch (error) {
        attemptStopwatch.stop();
        lastReason = 'network_error';
        _logFailure(
          requestId,
          modelId,
          index,
          attemptStopwatch.elapsed,
          error,
          lastReason,
          privateValues: privateValues,
        );
      } on http.ClientException catch (error) {
        attemptStopwatch.stop();
        lastReason = 'network_error';
        _logFailure(
          requestId,
          modelId,
          index,
          attemptStopwatch.elapsed,
          error,
          lastReason,
          privateValues: privateValues,
        );
      } on HandshakeException catch (error) {
        attemptStopwatch.stop();
        lastReason = 'tls_error';
        _logFailure(
          requestId,
          modelId,
          index,
          attemptStopwatch.elapsed,
          error,
          lastReason,
          privateValues: privateValues,
        );
        return _fallback(languageCode, requestId, lastReason);
      } on GenerativeAIException catch (error) {
        attemptStopwatch.stop();
        lastReason = _classifyServerMessage(error.message, modelId: modelId);
        _logFailure(
          requestId,
          modelId,
          index,
          attemptStopwatch.elapsed,
          error,
          lastReason,
          privateValues: privateValues,
        );
        if (!_shouldContinueForServerFailure(lastReason, error.message)) {
          return _fallback(languageCode, requestId, lastReason);
        }
      } catch (error) {
        attemptStopwatch.stop();
        lastReason = _classifyUnexpectedError(error);
        _logFailure(
          requestId,
          modelId,
          index,
          attemptStopwatch.elapsed,
          error,
          lastReason,
          privateValues: privateValues,
        );
      }

      if (index < modelIds.length - 1) {
        _log(
          requestId,
          'model_fallback_next next_attempt=${index + 2}/${modelIds.length} '
          'next_model=${modelIds[index + 1]} previous_reason=$lastReason',
        );
        if (lastReason == 'transient_server') {
          final backoff = Duration(
            milliseconds:
                _transientRetryBaseDelay.inMilliseconds * (1 << index),
          );
          final remaining = _requestBudget - overallStopwatch.elapsed;
          if (remaining <= Duration.zero) {
            return _fallback(languageCode, requestId, 'overall_timeout');
          }
          final delay = backoff < remaining ? backoff : remaining;
          _log(requestId, 'transient_backoff delay_ms=${delay.inMilliseconds}');
          await Future<void>.delayed(delay);
        }
      }
    }

    return _fallback(languageCode, requestId, lastReason);
  }

  void _logFailure(
    String requestId,
    String modelId,
    int index,
    Duration elapsed,
    Object error,
    String category, {
    Iterable<String> privateValues = const [],
  }) {
    final details = error is GenerativeAIException
        ? error.message
        : error.toString();
    final status = _httpStatusFrom(details);
    _log(
      requestId,
      'model_attempt_failed attempt=${index + 1}/${modelIds.length} '
      'model=$modelId elapsed_ms=${elapsed.inMilliseconds} '
      'category=$category ${status == null ? '' : 'http_status=$status '}'
      'exception_type=${error.runtimeType} '
      'details="${_safeDiagnostic(details, privateValues: privateValues)}"',
    );
  }

  String _classifyServerMessage(String message, {required String modelId}) {
    final lower = message.toLowerCase();
    if (_httpStatusFrom(message) == 400 ||
        lower.contains('invalid argument') ||
        lower.contains('malformed')) {
      return 'malformed_request';
    }
    if (_httpStatusFrom(message) == 401 ||
        lower.contains('api_key_invalid') ||
        lower.contains('unauthenticated') ||
        (lower.contains('api key') && lower.contains('invalid'))) {
      return 'authentication';
    }
    if (_httpStatusFrom(message) == 403 ||
        lower.contains('permission_denied') ||
        lower.contains('permission denied')) {
      if (lower.contains('model') || lower.contains(modelId.toLowerCase())) {
        return 'model_access';
      }
      return 'project_access';
    }
    if (_httpStatusFrom(message) == 404 ||
        lower.contains('model not found') ||
        lower.contains('not found')) {
      return 'invalid_model';
    }
    if (_httpStatusFrom(message) == 429 ||
        _httpStatusFrom(message) == 402 ||
        lower.contains('quota') ||
        lower.contains('resource_exhausted') ||
        lower.contains('resource exhausted') ||
        lower.contains('rate limit')) {
      return 'quota';
    }
    final status = _httpStatusFrom(message);
    if (status == 408 ||
        (status != null && status >= 500 && status <= 599) ||
        lower.contains('unavailable') ||
        lower.contains('overloaded')) {
      return 'transient_server';
    }
    return 'server_error';
  }

  bool _shouldContinueForServerFailure(String category, String message) {
    if (category == 'invalid_model' ||
        category == 'model_access' ||
        category == 'transient_server') {
      return true;
    }
    if (category == 'quota') {
      final lower = message.toLowerCase();
      return lower.contains('rate') ||
          lower.contains('per minute') ||
          lower.contains('too many requests');
    }
    return category == 'server_error';
  }

  String _classifyUnexpectedError(Object error) {
    if (error is HttpException) return 'network_error';
    return 'unexpected_error';
  }

  int? _httpStatusFrom(String message) {
    final match = RegExp(
      r'\b(400|401|402|403|404|408|429|5\d\d)\b',
    ).firstMatch(message);
    return match == null ? null : int.tryParse(match.group(1)!);
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

  String _newRequestId() {
    _globalRequestSequence++;
    return 'gemini-${DateTime.now().microsecondsSinceEpoch}-$_globalRequestSequence';
  }

  static void _log(String requestId, String message) {
    if (kDebugMode) debugPrint('[Gemini] request_id=$requestId $message');
  }

  String _fallback(String languageCode, String requestId, String reason) {
    _log(requestId, 'FALLBACK reason=$reason');
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

/// Production adapter; each attempt owns its HTTP client so a timed-out SDK
/// request can be aborted before the next model is attempted.
final class _GoogleGeminiSdkClient implements GeminiSdkClient {
  const _GoogleGeminiSdkClient();

  @override
  Future<String?> sendMessage({
    required String model,
    required String apiKey,
    required String systemInstruction,
    required List<Content> history,
    required String message,
    required Duration timeout,
  }) async {
    final httpClient = http.Client();
    try {
      final modelClient = GenerativeModel(
        model: model,
        apiKey: apiKey,
        httpClient: httpClient,
        systemInstruction: Content.system(systemInstruction),
        generationConfig: GenerationConfig(maxOutputTokens: 500),
      );
      final ChatSession chatSession = modelClient.startChat(history: history);
      final response = await chatSession
          .sendMessage(Content.text(message))
          .timeout(timeout);
      return response.text;
    } on TimeoutException {
      httpClient.close();
      rethrow;
    } finally {
      httpClient.close();
    }
  }
}
