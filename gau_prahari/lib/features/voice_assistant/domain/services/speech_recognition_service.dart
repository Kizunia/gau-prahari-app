/// Abstract interface for device speech recognition.
abstract class SpeechRecognitionService {
  bool get isListening;
  bool get isAvailable;

  /// Initialize the underlying speech recognition engine.
  Future<bool> initialize({
    Function(String error)? onError,
    Function(String status)? onStatus,
  });

  /// Check whether the app has microphone permission.
  Future<bool> hasPermission();

  /// Start listening for speech in the requested app [languageCode] ('en', 'hi', 'mr').
  Future<void> startListening({
    required String languageCode,
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(String error)? onError,
  });

  /// Stop listening and finalize any recognized words.
  Future<void> stopListening();

  /// Cancel listening immediately and discard partial recognition.
  Future<void> cancelListening();
}
