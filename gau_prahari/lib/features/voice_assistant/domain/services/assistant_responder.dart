import '../entities/chat_message.dart';

/// Abstract interface for generating assistant responses.
/// Implemented by AiAssistantService in Phase 2 and replaceable with fakes in tests.
abstract class AssistantResponder {
  /// Generate a text response using recent conversation history and language.
  Future<String> respond({
    required String query,
    required String languageCode,
    List<ChatMessage>? conversationContext,
  });
}
