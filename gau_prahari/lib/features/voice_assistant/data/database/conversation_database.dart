import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Database manager for persisting voice assistant conversations and messages.
class ConversationDatabase {
  static const String _databaseName = 'gau_prahari_conversations.db';
  static const int _databaseVersion = 1;

  static const String tableConversations = 'conversations';
  static const String tableMessages = 'messages';

  static ConversationDatabase? _instance;
  Database? _db;

  ConversationDatabase._internal();

  factory ConversationDatabase() {
    _instance ??= ConversationDatabase._internal();
    return _instance!;
  }

  /// Constructor for testing or injection with a custom/in-memory database instance.
  ConversationDatabase.withDatabase(Database database) : _db = database;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onConfigure(Database db) async {
    // Enable SQLite foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Conversations table
    await db.execute('''
      CREATE TABLE $tableConversations (
        id TEXT PRIMARY KEY,
        owner_id TEXT,
        title TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_opened_at INTEGER NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // Messages table with cascade delete
    await db.execute('''
      CREATE TABLE $tableMessages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        screen_name TEXT,
        action_name TEXT,
        action_status TEXT,
        FOREIGN KEY (conversation_id) REFERENCES $tableConversations(id) ON DELETE CASCADE
      );
    ''');

    // Composite index on conversation_id and created_at
    await db.execute('''
      CREATE INDEX idx_messages_conversation_created 
      ON $tableMessages(conversation_id, created_at);
    ''');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Support basic schema migrations for future phases
    if (oldVersion < 2) {
      // Future migration hooks
    }
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
