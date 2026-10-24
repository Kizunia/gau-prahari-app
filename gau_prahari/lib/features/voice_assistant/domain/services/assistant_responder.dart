import '../entities/chat_message.dart';

/// Abstract interface for generating assistant responses.
/// Implemented by [TemporaryLocalResponder] for offline testing,
/// and [AiAssistantService] for live Google Gemini API responses.
abstract class AssistantResponder {
  /// Generate a text response for the given [query] in the specified [languageCode].
  Future<String> respond({
    required String query,
    required String languageCode,
    List<ChatMessage>? conversationContext,
    Map<String, dynamic>? screenContext,
  });
}
