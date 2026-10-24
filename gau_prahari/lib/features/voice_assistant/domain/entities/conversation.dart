/// Domain entity representing a voice assistant conversation session.
class Conversation {
  final String id;
  final String? ownerId;
  final String? title;
  final int createdAt; // UTC Unix epoch millis
  final int updatedAt; // UTC Unix epoch millis
  final int lastOpenedAt; // UTC Unix epoch millis
  final bool isArchived;

  const Conversation({
    required this.id,
    this.ownerId,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.lastOpenedAt,
    this.isArchived = false,
  });

  Conversation copyWith({
    String? id,
    String? ownerId,
    String? title,
    int? createdAt,
    int? updatedAt,
    int? lastOpenedAt,
    bool? isArchived,
  }) {
    return Conversation(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'last_opened_at': lastOpenedAt,
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String?,
      title: map['title'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      lastOpenedAt: map['last_opened_at'] as int,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
