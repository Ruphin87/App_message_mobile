import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Base de données locale SQLite, servant de CACHE PERSISTANT pour les
/// contacts (amis) et les conversations/messages.
///
/// Principe "offline-first" :
/// - Au démarrage de l'écran Contacts ou Messages, on lit D'ABORD cette base
///   locale → affichage instantané, même hors connexion.
/// - En parallèle, on interroge Supabase (source de vérité) et on met à jour
///   la base locale avec ce qu'on reçoit → l'écran se rafraîchit ensuite
///   silencieusement avec les données les plus récentes.
/// - Le stream Realtime Supabase écrit aussi directement dans cette base au
///   fil de l'eau, donc le cache reste à jour même hors navigation explicite.
///
/// Une seule base de données partagée par toute l'app, isolée par
/// utilisateur via la colonne `owner_id` sur chaque table (utile si jamais
/// plusieurs comptes se connectent successivement sur le même appareil —
/// on ne veut pas mélanger les caches de deux utilisateurs différents).
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  static const _dbName = 'message_ko_local.db';
  static const _dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_users (
            owner_id TEXT NOT NULL,
            id TEXT NOT NULL,
            nom TEXT NOT NULL,
            email TEXT NOT NULL,
            photo TEXT,
            bio TEXT,
            date_creation TEXT NOT NULL,
            PRIMARY KEY (owner_id, id)
          )
        ''');

        await db.execute('''
          CREATE TABLE local_friends (
            owner_id TEXT NOT NULL,
            id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            friend_id TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            friend_profile_id TEXT,
            PRIMARY KEY (owner_id, id)
          )
        ''');

        await db.execute('''
          CREATE TABLE local_conversations (
            owner_id TEXT NOT NULL,
            id TEXT NOT NULL,
            user1 TEXT NOT NULL,
            user2 TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_message_at TEXT NOT NULL,
            other_user_id TEXT,
            last_message TEXT,
            unread_count INTEGER NOT NULL DEFAULT 0,
            deleted_for TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (owner_id, id)
          )
        ''');

        await db.execute('''
          CREATE TABLE local_messages (
            owner_id TEXT NOT NULL,
            id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            message TEXT NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            delivered_at TEXT,
            is_deleted_for_everyone INTEGER NOT NULL DEFAULT 0,
            deleted_for TEXT NOT NULL DEFAULT '',
            reply_to_id TEXT,
            PRIMARY KEY (owner_id, id)
          )
        ''');

        await db.execute('''
          CREATE TABLE local_message_reactions (
            owner_id TEXT NOT NULL,
            id TEXT NOT NULL,
            message_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            emoji TEXT NOT NULL,
            created_at TEXT NOT NULL,
            PRIMARY KEY (owner_id, id)
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_local_messages_conv ON local_messages(owner_id, conversation_id)',
        );
        await db.execute(
          'CREATE INDEX idx_local_friends_status ON local_friends(owner_id, status)',
        );
        await db.execute(
          'CREATE INDEX idx_local_reactions_message ON local_message_reactions(owner_id, message_id)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Bases créées avant l'ajout de la suppression/reply/réactions :
          // on ajoute les colonnes manquantes et la nouvelle table, sans
          // perdre les données déjà en cache.
          await db.execute(
            'ALTER TABLE local_messages ADD COLUMN is_deleted_for_everyone INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            "ALTER TABLE local_messages ADD COLUMN deleted_for TEXT NOT NULL DEFAULT ''",
          );
          await db.execute('ALTER TABLE local_messages ADD COLUMN reply_to_id TEXT');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS local_message_reactions (
              owner_id TEXT NOT NULL,
              id TEXT NOT NULL,
              message_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              emoji TEXT NOT NULL,
              created_at TEXT NOT NULL,
              PRIMARY KEY (owner_id, id)
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_local_reactions_message ON local_message_reactions(owner_id, message_id)',
          );
        }
        if (oldVersion < 3) {
          // Bases créées avant l'ajout de la suppression de conversation
          // entière (distincte de la suppression d'un message) : on ajoute
          // la colonne manquante sans perdre le cache déjà présent.
          await db.execute(
            "ALTER TABLE local_conversations ADD COLUMN deleted_for TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  // ==================== USERS (profils, pour jointures locales) ====================

  Future<void> upsertUser(String ownerId, Map<String, dynamic> userRow) async {
    final db = await database;
    await db.insert(
      'local_users',
      {...userRow, 'owner_id': ownerId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertUsers(String ownerId, List<Map<String, dynamic>> userRows) async {
    if (userRows.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final row in userRows) {
      batch.insert(
        'local_users',
        {...row, 'owner_id': ownerId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>?> getUser(String ownerId, String userId) async {
    final db = await database;
    final rows = await db.query(
      'local_users',
      where: 'owner_id = ? AND id = ?',
      whereArgs: [ownerId, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ==================== FRIENDS ====================

  Future<void> upsertFriends(String ownerId, List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'local_friends',
        {...row, 'owner_id': ownerId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getFriendsByStatus(
    String ownerId, {
    required String status,
    required String column, // 'user_id' ou 'friend_id'
    required String currentUserId,
  }) async {
    final db = await database;
    return db.query(
      'local_friends',
      where: 'owner_id = ? AND status = ? AND $column = ?',
      whereArgs: [ownerId, status, currentUserId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteFriend(String ownerId, String friendRowId) async {
    final db = await database;
    await db.delete(
      'local_friends',
      where: 'owner_id = ? AND id = ?',
      whereArgs: [ownerId, friendRowId],
    );
  }

  Future<void> clearFriends(String ownerId) async {
    final db = await database;
    await db.delete('local_friends', where: 'owner_id = ?', whereArgs: [ownerId]);
  }

  // ==================== CONVERSATIONS ====================

  Future<void> upsertConversations(String ownerId, List<Map<String, dynamic>> rows) async {
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'local_conversations',
        {...row, 'owner_id': ownerId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getConversations(String ownerId) async {
    final db = await database;
    return db.query(
      'local_conversations',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'last_message_at DESC',
    );
  }

  /// Retire une conversation du cache local (utilisé après une suppression
  /// de conversation réussie côté serveur, pour qu'elle disparaisse
  /// immédiatement de la liste sans attendre le prochain sync réseau).
  Future<void> deleteConversation(String ownerId, String conversationId) async {
    final db = await database;
    await db.delete(
      'local_conversations',
      where: 'owner_id = ? AND id = ?',
      whereArgs: [ownerId, conversationId],
    );
  }

  // ==================== MESSAGES ====================

  Future<void> upsertMessages(String ownerId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'local_messages',
        {...row, 'owner_id': ownerId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markMessagesAsDelivered(
    String ownerId,
    String conversationId,
    String deliveredAt,
  ) async {
    final db = await database;
    await db.update(
      'local_messages',
      {'delivered_at': deliveredAt},
      where:
          'owner_id = ? AND conversation_id = ? AND delivered_at IS NULL AND sender_id != ?',
      whereArgs: [ownerId, conversationId, ownerId],
    );
  }

  Future<void> markMessagesAsRead(
    String ownerId,
    String conversationId,
    String readAt,
  ) async {
    final db = await database;
    final batch = db.batch();
    batch.update(
      'local_messages',
      {
        'is_read': 1,
        'delivered_at': readAt,
      },
      where: 'owner_id = ? AND conversation_id = ? AND is_read = 0 AND sender_id != ?',
      whereArgs: [ownerId, conversationId, ownerId],
    );
    batch.update(
      'local_conversations',
      {'unread_count': 0},
      where: 'owner_id = ? AND id = ?',
      whereArgs: [ownerId, conversationId],
    );
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMessages(
    String ownerId,
    String conversationId,
  ) async {
    final db = await database;
    return db.query(
      'local_messages',
      where: 'owner_id = ? AND conversation_id = ?',
      whereArgs: [ownerId, conversationId],
      orderBy: 'created_at ASC',
    );
  }

  /// Supprime une ligne de message du cache local (utilisé après une
  /// suppression "pour moi" réussie côté serveur, pour ne pas avoir à
  /// attendre le prochain sync réseau pour le faire disparaître).
  Future<void> deleteMessage(String ownerId, String messageId) async {
    final db = await database;
    await db.delete(
      'local_messages',
      where: 'owner_id = ? AND id = ?',
      whereArgs: [ownerId, messageId],
    );
  }

  // ==================== RÉACTIONS ====================

  Future<void> upsertReactions(String ownerId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(
        'local_message_reactions',
        {...row, 'owner_id': ownerId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getReactionsForMessages(
    String ownerId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(messageIds.length, '?').join(',');
    return db.rawQuery(
      'SELECT * FROM local_message_reactions WHERE owner_id = ? AND message_id IN ($placeholders)',
      [ownerId, ...messageIds],
    );
  }

  Future<void> deleteReaction(String ownerId, String messageId, String userId) async {
    final db = await database;
    await db.delete(
      'local_message_reactions',
      where: 'owner_id = ? AND message_id = ? AND user_id = ?',
      whereArgs: [ownerId, messageId, userId],
    );
  }

  /// Supprime toutes les données locales d'un utilisateur (à appeler à la
  /// déconnexion, pour ne jamais laisser le cache d'un compte visible par
  /// un autre compte sur le même appareil).
  Future<void> clearAllForUser(String ownerId) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('local_users', where: 'owner_id = ?', whereArgs: [ownerId]);
    batch.delete('local_friends', where: 'owner_id = ?', whereArgs: [ownerId]);
    batch.delete('local_conversations', where: 'owner_id = ?', whereArgs: [ownerId]);
    batch.delete('local_messages', where: 'owner_id = ?', whereArgs: [ownerId]);
    batch.delete('local_message_reactions', where: 'owner_id = ?', whereArgs: [ownerId]);
    await batch.commit(noResult: true);
  }
}
