/// Template for Gemini AI Configuration for Gau-Prahari Voice Assistant.
///
/// Copy this file to `ai_config.dart` and enter your Gemini API key:
///   cp lib/core/config/ai_config.example.dart lib/core/config/ai_config.dart
///
/// Free API keys can be generated at Google AI Studio:
/// https://aistudio.google.com/
class AiConfig {
  /// Gemini API Key from Google AI Studio.
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';

  /// Primary Gemini model ID.
  static const String defaultModel = 'gemini-3-flash-preview';

  /// Secondary fallback model in case of quota or model availability issues.
  static const String fallbackModel = 'gemini-3.5-flash';

  /// Request timeout in seconds.
  static const int requestTimeoutSeconds = 15;
}
