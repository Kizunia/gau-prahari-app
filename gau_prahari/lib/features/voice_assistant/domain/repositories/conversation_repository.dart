import '../entities/conversation.dart';
import '../entities/chat_message.dart';

/// Contract for persistent storage and retrieval of conversations and messages.
abstract class ConversationRepository {
  /// Create and persist a new conversation.
  Future<Conversation> createConversation({
    String? id,
    String? ownerId,
    String? title,
  });

  /// Update conversation metadata (e.g. title, timestamps).
  Future<void> updateConversation(Conversation conversation);

  /// Fetch a conversation by its ID.
  Future<Conversation?> getConversationById(String conversationId);

  /// Get the most recently opened conversation for the specified owner.
  Future<Conversation?> getLastOpenedConversation({String? ownerId});

  /// List all conversations for the owner, ordered by most recently opened/updated.
  Future<List<Conversation>> getConversations({String? ownerId});

  /// Update the last_opened_at timestamp for a conversation.
  Future<void> markConversationOpened(String conversationId);

  /// Add and persist a message to an existing conversation.
  Future<ChatMessage> addMessage(ChatMessage message);

  /// Get all messages for a conversation, ordered chronologically (oldest first).
  Future<List<ChatMessage>> getMessages(String conversationId);

  /// Get recent messages for context window (oldest first, limited to [limit]).
  Future<List<ChatMessage>> getRecentMessages(
    String conversationId, {
    int limit = 20,
  });

  /// Delete a conversation and its child messages (cascade).
  Future<void> deleteConversation(String conversationId);
}
