import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../domain/services/speech_output_service.dart';

/// Concrete implementation of [SpeechOutputService] using `flutter_tts`.
class SpeechOutputServiceImpl implements SpeechOutputService {
  final FlutterTts _tts;
  bool _isSpeaking = false;
  bool _isInitialized = false;
  Function()? _currentOnDone;

  SpeechOutputServiceImpl({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<void> initialize({
    Function()? onStart,
    Function()? onDone,
    Function(String error)? onError,
  }) async {
    if (_isInitialized) return;

    try {
      await _tts.setSpeechRate(0.48); // Natural conversational rate for clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        onStart?.call();
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _currentOnDone?.call();
        _currentOnDone = null;
        onDone?.call();
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _currentOnDone = null;
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _currentOnDone = null;
        debugPrint('TTS Error: $msg');
        onError?.call(msg.toString());
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  String _resolveTtsLocale(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return 'hi-IN';
      case 'mr':
        return 'mr-IN';
      case 'en':
      default:
        return 'en-IN';
    }
  }

  @override
  Future<bool> isLanguageAvailable(String languageCode) async {
    try {
      final locale = _resolveTtsLocale(languageCode);
      final res = await _tts.isLanguageAvailable(locale);
      if (res is bool) return res;
      if (res is int) return res == 1;
      return res != null;
    } catch (e) {
      debugPrint('Error checking TTS language availability: $e');
      return false;
    }
  }

  @override
  Future<void> speak(
    String text, {
    required String languageCode,
    Function()? onDone,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      await stop(); // Stop any ongoing speech before starting new utterance

      _currentOnDone = onDone;
      final locale = _resolveTtsLocale(languageCode);

      // Verify availability; fallback gracefully to standard English if unavailable
      final available = await isLanguageAvailable(languageCode);
      if (available) {
        await _tts.setLanguage(locale);
      } else {
        debugPrint('TTS locale $locale not available, falling back to en-US');
        await _tts.setLanguage('en-US');
      }

      _isSpeaking = true;
      final result = await _tts.speak(text);
      if (result == 0) {
        _isSpeaking = false;
        _currentOnDone?.call();
        _currentOnDone = null;
      }
    } catch (e) {
      _isSpeaking = false;
      _currentOnDone = null;
      debugPrint('TTS speak exception: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      _isSpeaking = false;
      _currentOnDone = null;
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }
}
