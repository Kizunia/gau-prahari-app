import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../database/conversation_database.dart';

/// SQLite-backed implementation of [ConversationRepository].
class ConversationRepositoryImpl implements ConversationRepository {
  final ConversationDatabase _dbHelper;

  ConversationRepositoryImpl({ConversationDatabase? dbHelper})
    : _dbHelper = dbHelper ?? ConversationDatabase();

  String _generateId(String prefix) {
    final rand = Random().nextInt(10000).toString().padLeft(4, '0');
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }

  @override
  Future<Conversation> createConversation({
    String? id,
    String? ownerId,
    String? title,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final convId = id ?? _generateId('conv');

    final conversation = Conversation(
      id: convId,
      ownerId: ownerId,
      title: title ?? 'New Conversation',
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
      isArchived: false,
    );

    await db.insert(
      ConversationDatabase.tableConversations,
      conversation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return conversation;
  }

  @override
  Future<void> updateConversation(Conversation conversation) async {
    final db = await _dbHelper.database;
    await db.update(
      ConversationDatabase.tableConversations,
      conversation.toMap(),
      where: 'id = ?',
      whereArgs: [conversation.id],
    );
  }

  @override
  Future<Conversation?> getConversationById(String conversationId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      ConversationDatabase.tableConversations,
      where: 'id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Conversation.fromMap(maps.first);
  }

  @override
  Future<Conversation?> getLastOpenedConversation({String? ownerId}) async {
    final db = await _dbHelper.database;
    String whereClause = 'is_archived = 0';
    List<dynamic> whereArgs = [];

    if (ownerId != null) {
      whereClause += ' AND owner_id = ?';
      whereArgs.add(ownerId);
    } else {
      whereClause += ' AND owner_id IS NULL';
    }

    final maps = await db.query(
      ConversationDatabase.tableConversations,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'last_opened_at DESC, updated_at DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Conversation.fromMap(maps.first);
  }

  @override
  Future<List<Conversation>> getConversations({String? ownerId}) async {
    final db = await _dbHelper.database;
    String whereClause = 'is_archived = 0';
    List<dynamic> whereArgs = [];

    if (ownerId != null) {
      whereClause += ' AND owner_id = ?';
      whereArgs.add(ownerId);
    } else {
      whereClause += ' AND owner_id IS NULL';
    }

    final maps = await db.query(
      ConversationDatabase.tableConversations,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'last_opened_at DESC, updated_at DESC',
    );

    return maps.map((m) => Conversation.fromMap(m)).toList();
  }

  @override
  Future<void> markConversationOpened(String conversationId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.update(
      ConversationDatabase.tableConversations,
      {'last_opened_at': now},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  @override
  Future<ChatMessage> addMessage(ChatMessage message) async {
    final db = await _dbHelper.database;
    final msgId = message.id.isEmpty ? _generateId('msg') : message.id;
    final toSave = message.copyWith(id: msgId);

    await db.insert(
      ConversationDatabase.tableMessages,
      toSave.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update conversation updated_at and optionally title if default
    final conv = await getConversationById(message.conversationId);
    if (conv != null) {
      String? newTitle = conv.title;
      if ((newTitle == null || newTitle == 'New Conversation') &&
          message.isUser) {
        // Derive title from first user query (max 30 chars)
        final trimmed = message.content.trim();
        newTitle = trimmed.length > 30
            ? '${trimmed.substring(0, 30)}...'
            : trimmed;
      }

      final updateData = <String, dynamic>{
        'updated_at': message.createdAt,
        'last_opened_at': message.createdAt,
      };
      if (newTitle != null) {
        updateData['title'] = newTitle;
      }

      await db.update(
        ConversationDatabase.tableConversations,
        updateData,
        where: 'id = ?',
        whereArgs: [message.conversationId],
      );
    }

    return toSave;
  }

  List<ChatMessage> _deduplicate(List<ChatMessage> rawMessages, {Database? db}) {
    if (rawMessages.length <= 1) return rawMessages;

    final deduplicated = <ChatMessage>[];
    final toDeleteIds = <String>[];

    for (int i = 0; i < rawMessages.length; i++) {
      final current = rawMessages[i];
      if (deduplicated.isEmpty) {
        deduplicated.add(current);
        continue;
      }

      final prev = deduplicated.last;

      // Duplicate user message check: exact same content and role within 10 seconds
      if (current.role == 'user' &&
          prev.role == 'user' &&
          current.content.trim().toLowerCase() ==
              prev.content.trim().toLowerCase() &&
          (current.createdAt - prev.createdAt).abs() < 10000) {
        if (current.id.isNotEmpty) toDeleteIds.add(current.id);
        continue;
      }

      // Duplicate assistant message check: consecutive assistant messages within 10 seconds
      if (current.role == 'assistant' &&
          prev.role == 'assistant' &&
          (current.createdAt - prev.createdAt).abs() < 10000) {
        if (current.id.isNotEmpty) toDeleteIds.add(current.id);
        continue;
      }

      deduplicated.add(current);
    }

    if (db != null && toDeleteIds.isNotEmpty) {
      for (final id in toDeleteIds) {
        db
            .delete(
              ConversationDatabase.tableMessages,
              where: 'id = ?',
              whereArgs: [id],
            )
            .catchError((_) => 0);
      }
    }

    return deduplicated;
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      ConversationDatabase.tableMessages,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );

    final raw = maps.map((m) => ChatMessage.fromMap(m)).toList();
    return _deduplicate(raw, db: db);
  }

  @override
  Future<List<ChatMessage>> getRecentMessages(
    String conversationId, {
    int limit = 20,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      ConversationDatabase.tableMessages,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    // Return in chronological order (oldest to newest within the window)
    final raw = maps.map((m) => ChatMessage.fromMap(m)).toList().reversed.toList();
    return _deduplicate(raw, db: db);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final db = await _dbHelper.database;
    await db.delete(
      ConversationDatabase.tableConversations,
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }
}
