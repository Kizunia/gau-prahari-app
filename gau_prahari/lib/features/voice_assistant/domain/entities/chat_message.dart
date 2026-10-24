/// Domain entity representing a single message within a conversation.
class ChatMessage {
  final String id;
  final String conversationId;
  final String role; // 'user' or 'assistant'
  final String content;
  final int createdAt; // UTC Unix epoch millis
  final String? screenName;
  final String? actionName;
  final String? actionStatus; // 'succeeded', 'failed', or 'not_applicable'

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.screenName,
    this.actionName,
    this.actionStatus,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    int? createdAt,
    String? screenName,
    String? actionName,
    String? actionStatus,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      screenName: screenName ?? this.screenName,
      actionName: actionName ?? this.actionName,
      actionStatus: actionStatus ?? this.actionStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'created_at': createdAt,
      'screen_name': screenName,
      'action_name': actionName,
      'action_status': actionStatus,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      createdAt: map['created_at'] as int,
      screenName: map['screen_name'] as String?,
      actionName: map['action_name'] as String?,
      actionStatus: map['action_status'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
