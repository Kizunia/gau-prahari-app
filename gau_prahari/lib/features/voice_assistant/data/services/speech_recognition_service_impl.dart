import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../domain/services/speech_recognition_service.dart';

/// Concrete implementation of [SpeechRecognitionService] using `speech_to_text`.
class SpeechRecognitionServiceImpl implements SpeechRecognitionService {
  final stt.SpeechToText _speech;
  bool _isInitialized = false;
  List<stt.LocaleName> _availableLocales = [];

  SpeechRecognitionServiceImpl({stt.SpeechToText? speech})
    : _speech = speech ?? stt.SpeechToText();

  @override
  bool get isListening => _speech.isListening;

  @override
  bool get isAvailable => _speech.isAvailable;

  @override
  Future<bool> initialize({
    Function(String error)? onError,
    Function(String status)? onStatus,
  }) async {
    if (_isInitialized && _speech.isAvailable) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (val) {
          debugPrint('SpeechRecognition error: ${val.errorMsg}');
          onError?.call(val.errorMsg);
        },
        onStatus: (val) {
          debugPrint('SpeechRecognition status: $val');
          onStatus?.call(val);
        },
      );

      if (_isInitialized) {
        try {
          _availableLocales = await _speech.locales();
        } catch (e) {
          debugPrint('Failed to query device locales: $e');
        }
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('SpeechRecognition initialize exception: $e');
      onError?.call(e.toString());
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    return _speech.hasPermission;
  }

  String _resolveLocaleId(String languageCode) {
    if (_availableLocales.isEmpty) {
      // Common default locale mapping for India
      switch (languageCode) {
        case 'hi':
          return 'hi_IN';
        case 'mr':
          return 'mr_IN';
        case 'en':
        default:
          return 'en_IN';
      }
    }

    // Try finding exact or matching locale for the language code
    for (final loc in _availableLocales) {
      final id = loc.localeId.toLowerCase().replaceAll('-', '_');
      if (id.startsWith('${languageCode.toLowerCase()}_')) {
        return loc.localeId;
      }
    }

    for (final loc in _availableLocales) {
      if (loc.localeId.toLowerCase().startsWith(languageCode.toLowerCase())) {
        return loc.localeId;
      }
    }

    return languageCode == 'hi'
        ? 'hi_IN'
        : languageCode == 'mr'
        ? 'mr_IN'
        : 'en_IN';
  }

  @override
  Future<void> startListening({
    required String languageCode,
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(String error)? onError,
  }) async {
    if (_speech.isListening) {
      debugPrint('Already listening, ignoring duplicate startListening call.');
      return;
    }

    if (!_isInitialized) {
      final ok = await initialize(onError: onError);
      if (!ok) {
        onError?.call('speechInitFailed');
        return;
      }
    }

    final localeId = _resolveLocaleId(languageCode);
    debugPrint('Starting speech recognition with localeId: $localeId');

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('Speech listen exception: $e');
      onError?.call(e.toString());
    }
  }

  @override
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  @override
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
