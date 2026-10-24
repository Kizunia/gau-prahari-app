import '../../domain/entities/chat_message.dart';
import '../../domain/services/assistant_responder.dart';

/// ============================================================================
/// TEMPORARY LOCAL RESPONDER — PHASE 1 DEVELOPMENT & TESTING ONLY
/// ============================================================================
/// This class provides deterministic, local acknowledgments for testing the
/// voice assistant's speech-to-text, transcript, SQLite persistence, and text-to-speech.
///
/// It does NOT connect to Gemini, any AI model, or any external network API.
/// In Phase 2, this implementation will be replaced by AiAssistantService.
/// ============================================================================
class TemporaryLocalResponder implements AssistantResponder {
  const TemporaryLocalResponder();

  @override
  Future<String> respond({
    required String query,
    required String languageCode,
    List<ChatMessage>? conversationContext,
  }) async {
    final cleanQuery = query.trim();

    switch (languageCode) {
      case 'hi':
        return 'मैंने सुना: "$cleanQuery"। गौ-प्रहरी फेज़ 1 वॉयस असिस्टेंट ठीक से काम कर रहा है।';
      case 'mr':
        return 'मी ऐकले: "$cleanQuery". गो-प्रहरी फेज 1 व्हॉइस असिस्टंट व्यवस्थित काम करत आहे.';
      case 'en':
      default:
        return 'I heard: "$cleanQuery". Gau-Prahari Phase 1 voice assistant is working properly.';
    }
  }
}
