/// Abstract interface for Text-to-Speech (TTS) output.
abstract class SpeechOutputService {
  bool get isSpeaking;

  /// Initialize the TTS engine and set handlers.
  Future<void> initialize({
    Function()? onStart,
    Function()? onDone,
    Function(String error)? onError,
  });

  /// Check whether a language voice is available on this device.
  Future<bool> isLanguageAvailable(String languageCode);

  /// Speak the given [text] in the requested app [languageCode] ('en', 'hi', 'mr').
  Future<void> speak(
    String text, {
    required String languageCode,
    Function()? onDone,
  });

  /// Immediately stop any ongoing TTS speech.
  Future<void> stop();
}
