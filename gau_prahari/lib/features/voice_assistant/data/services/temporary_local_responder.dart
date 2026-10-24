import '../../domain/entities/chat_message.dart';
import '../../domain/services/assistant_responder.dart';

/// ============================================================================
/// TEMPORARY LOCAL RESPONDER — TEST & OFFLINE BENCHMARK
/// ============================================================================
/// This class provides deterministic, local acknowledgments for testing the
/// voice assistant's speech-to-text, transcript, SQLite persistence, and text-to-speech.
///
/// It does NOT connect to Gemini or any external network API.
/// In production, [AiAssistantService] is used.
/// ============================================================================
class TemporaryLocalResponder implements AssistantResponder {
  const TemporaryLocalResponder();

  @override
  Future<String> respond({
    required String query,
    required String languageCode,
    List<ChatMessage>? conversationContext,
    Map<String, dynamic>? screenContext,
  }) async {
    final cleanQuery = query.trim();

    switch (languageCode) {
      case 'hi':
        return 'मैंने सुना: "$cleanQuery"। गौ-प्रहरी वॉयस असिस्टेंट ठीक से काम कर रहा है।';
      case 'mr':
        return 'मी ऐकले: "$cleanQuery". गो-प्रहरी व्हॉइस असिस्टंट व्यवस्थित काम करत आहे.';
      case 'en':
      default:
        return 'I heard: "$cleanQuery". Gau-Prahari voice assistant is working properly.';
    }
  }
}
