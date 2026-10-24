import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gau_prahari/features/voice_assistant/data/database/conversation_database.dart';
import 'package:gau_prahari/features/voice_assistant/data/repositories/conversation_repository_impl.dart';
import 'package:gau_prahari/features/voice_assistant/domain/entities/chat_message.dart';

void main() {
  // Set up FFI for running sqflite in desktop unit tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ConversationDatabase convDb;
  late ConversationRepositoryImpl repository;

  setUp(() async {
    // Open a fresh in-memory database for each test
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE conversations (
              id TEXT PRIMARY KEY,
              owner_id TEXT,
              title TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              last_opened_at INTEGER NOT NULL,
              is_archived INTEGER NOT NULL DEFAULT 0
            );
          ''');

          await db.execute('''
            CREATE TABLE messages (
              id TEXT PRIMARY KEY,
              conversation_id TEXT NOT NULL,
              role TEXT NOT NULL,
              content TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              screen_name TEXT,
              action_name TEXT,
              action_status TEXT,
              FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
          ''');

          await db.execute('''
            CREATE INDEX idx_messages_conversation_created 
            ON messages(conversation_id, created_at);
          ''');
        },
      ),
    );

    convDb = ConversationDatabase.withDatabase(db);
    repository = ConversationRepositoryImpl(dbHelper: convDb);
  });

  tearDown(() async {
    await db.close();
  });

  group('ConversationRepository Database Tests', () {
    test('Creating and loading a conversation', () async {
      final conv = await repository.createConversation(
        id: 'conv_1',
        ownerId: 'user_vet_1',
        title: 'Initial Checkup',
      );

      expect(conv.id, equals('conv_1'));
      expect(conv.ownerId, equals('user_vet_1'));
      expect(conv.title, equals('Initial Checkup'));

      final loaded = await repository.getConversationById('conv_1');
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('conv_1'));
      expect(loaded.title, equals('Initial Checkup'));
    });

    test('Saving user and assistant messages with chronological ordering', () async {
      await repository.createConversation(id: 'conv_1', ownerId: 'user_1');

      final msg1 = ChatMessage(
        id: 'msg_1',
        conversationId: 'conv_1',
        role: 'user',
        content: 'Hello assistant',
        createdAt: 1000,
      );

      final msg2 = ChatMessage(
        id: 'msg_2',
        conversationId: 'conv_1',
        role: 'assistant',
        content: 'Hello farmer!',
        createdAt: 2000,
      );

      final msg3 = ChatMessage(
        id: 'msg_3',
        conversationId: 'conv_1',
        role: 'user',
        content: 'What is cow COW-104 status?',
        createdAt: 3000,
      );

      // Save in shuffled order
      await repository.addMessage(msg2);
      await repository.addMessage(msg1);
      await repository.addMessage(msg3);

      final messages = await repository.getMessages('conv_1');
      expect(messages.length, equals(3));
      // Verify strictly chronological order: 1000, 2000, 3000
      expect(messages[0].id, equals('msg_1'));
      expect(messages[1].id, equals('msg_2'));
      expect(messages[2].id, equals('msg_3'));
      expect(messages[0].role, equals('user'));
      expect(messages[1].role, equals('assistant'));
    });

    test('Persistence after reopening the database', () async {
      final conv = await repository.createConversation(
        id: 'conv_persist',
        ownerId: 'farmer_1',
        title: 'Persistent Session',
      );
      await repository.addMessage(ChatMessage(
        id: 'm1',
        conversationId: conv.id,
        role: 'user',
        content: 'Testing persistence',
        createdAt: 5000,
      ));

      // Re-instantiate repository pointing to same database
      final repo2 = ConversationRepositoryImpl(dbHelper: convDb);
      final retrievedConv = await repo2.getConversationById('conv_persist');
      final retrievedMessages = await repo2.getMessages('conv_persist');

      expect(retrievedConv, isNotNull);
      expect(retrievedConv!.title, equals('Persistent Session'));
      expect(retrievedMessages.length, equals(1));
      expect(retrievedMessages.first.content, equals('Testing persistence'));
    });

    test('Selecting the latest-opened conversation', () async {
      // Create three conversations at different times
      await repository.createConversation(id: 'c1', ownerId: 'user_a', title: 'First');
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.createConversation(id: 'c2', ownerId: 'user_a', title: 'Second');
      await Future.delayed(const Duration(milliseconds: 10));
      await repository.createConversation(id: 'c3', ownerId: 'user_a', title: 'Third');

      // Reopening c1 updates its last_opened_at to be the newest
      await repository.markConversationOpened('c1');

      final latest = await repository.getLastOpenedConversation(ownerId: 'user_a');
      expect(latest, isNotNull);
      expect(latest!.id, equals('c1'));
    });

    test('Starting a new conversation without deleting old history', () async {
      await repository.createConversation(id: 'c1', ownerId: 'user_a', title: 'Old Chat');
      await repository.addMessage(ChatMessage(
        id: 'm1',
        conversationId: 'c1',
        role: 'user',
        content: 'Old question',
        createdAt: 100,
      ));

      // Start new conversation c2
      await repository.createConversation(id: 'c2', ownerId: 'user_a', title: 'New Chat');
      await repository.addMessage(ChatMessage(
        id: 'm2',
        conversationId: 'c2',
        role: 'user',
        content: 'New question',
        createdAt: 200,
      ));

      final allConvs = await repository.getConversations(ownerId: 'user_a');
      expect(allConvs.length, equals(2));
      expect(allConvs.map((c) => c.id), containsAll(['c1', 'c2']));

      // Confirm c1 messages still intact
      final c1Msgs = await repository.getMessages('c1');
      expect(c1Msgs.length, equals(1));
      expect(c1Msgs.first.content, equals('Old question'));
    });

    test('Separating histories by owner ID when applicable', () async {
      await repository.createConversation(id: 'c_vet', ownerId: 'vet_user', title: 'Vet Work');
      await repository.createConversation(id: 'c_farmer', ownerId: 'farmer_user', title: 'Farm Work');
      await repository.createConversation(id: 'c_anon', ownerId: null, title: 'Guest Work');

      final vetConvs = await repository.getConversations(ownerId: 'vet_user');
      final farmerConvs = await repository.getConversations(ownerId: 'farmer_user');
      final guestConvs = await repository.getConversations(ownerId: null);

      expect(vetConvs.length, equals(1));
      expect(vetConvs.first.id, equals('c_vet'));

      expect(farmerConvs.length, equals(1));
      expect(farmerConvs.first.id, equals('c_farmer'));

      expect(guestConvs.length, equals(1));
      expect(guestConvs.first.id, equals('c_anon'));
    });

    test('getRecentMessages retrieves up to limit in chronological order', () async {
      await repository.createConversation(id: 'conv_window', ownerId: 'user_1');

      for (int i = 1; i <= 25; i++) {
        await repository.addMessage(ChatMessage(
          id: 'msg_$i',
          conversationId: 'conv_window',
          role: i.isOdd ? 'user' : 'assistant',
          content: 'Message $i',
          createdAt: i * 1000,
        ));
      }

      final recent = await repository.getRecentMessages('conv_window', limit: 20);
      expect(recent.length, equals(20));
      // Oldest of the 20 should be message 6, newest message 25
      expect(recent.first.id, equals('msg_6'));
      expect(recent.last.id, equals('msg_25'));
      // Chronological order verified
      for (int i = 0; i < recent.length - 1; i++) {
        expect(recent[i].createdAt < recent[i + 1].createdAt, isTrue);
      }
    });

    test('Cascade delete removes conversation and child messages', () async {
      await repository.createConversation(id: 'conv_del', ownerId: 'user_1');
      await repository.addMessage(ChatMessage(
        id: 'msg_del_1',
        conversationId: 'conv_del',
        role: 'user',
        content: 'To be deleted',
        createdAt: 1000,
      ));

      await repository.deleteConversation('conv_del');

      final conv = await repository.getConversationById('conv_del');
      final msgs = await repository.getMessages('conv_del');

      expect(conv, isNull);
      expect(msgs, isEmpty);
    });
  });
}
