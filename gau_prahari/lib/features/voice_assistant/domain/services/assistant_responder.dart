import '../entities/chat_message.dart';

/// Abstract interface for generating assistant responses.
/// In Phase 1, this is satisfied by [TemporaryLocalResponder].
/// In Phase 2, this will be replaced by [AiAssistantService] (Gemini API).
abstract class AssistantResponder {
  /// Generate a text response for the given [query] in the specified [languageCode].
  Future<String> respond({
    required String query,
    required String languageCode,
    List<ChatMessage>? conversationContext,
  });
}
