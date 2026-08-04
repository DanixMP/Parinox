import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/message.dart';

/// Local sqflite cache — messages per room + last_id cursor for WS resync.
class LocalCache {
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'team_app_cache.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY,
            room_id INTEGER NOT NULL,
            sender_id INTEGER NOT NULL,
            content TEXT,
            image_path TEXT,
            created_at TEXT NOT NULL,
            sender_display_name TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_cache_messages_room ON messages(room_id, id)',
        );
        await db.execute('''
          CREATE TABLE room_cursors (
            room_id INTEGER PRIMARY KEY,
            last_message_id INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  Future<int> getLastMessageId(int roomId) async {
    final database = await db;
    final rows = await database.query(
      'room_cursors',
      where: 'room_id = ?',
      whereArgs: [roomId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.first['last_message_id'] as int;
  }

  Future<void> setLastMessageId(int roomId, int messageId) async {
    final database = await db;
    final current = await getLastMessageId(roomId);
    if (messageId <= current) return;
    await database.insert(
      'room_cursors',
      {'room_id': roomId, 'last_message_id': messageId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMessage(Message msg) async {
    final database = await db;
    await database.insert(
      'messages',
      msg.toCacheMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await setLastMessageId(msg.roomId, msg.id);
  }

  Future<List<Message>> messagesForRoom(int roomId, {int limit = 200}) async {
    final database = await db;
    final rows = await database.query(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map((r) => Message.fromJson(r)).toList();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
