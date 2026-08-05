import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/message.dart';

/// Local message cache + last_id cursor for WS resync.
///
/// Uses sqflite on mobile/desktop; falls back to in-memory maps on web.
class LocalCache {
  Database? _db;
  final Map<int, int> _webCursors = {};
  final Map<int, List<Message>> _webMessages = {};

  Future<Database> get db async {
    if (kIsWeb) {
      throw UnsupportedError('sqflite is not available on web');
    }
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'team_app_cache.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY,
            room_id INTEGER NOT NULL,
            sender_id INTEGER NOT NULL,
            content TEXT,
            image_path TEXT,
            media_path TEXT,
            media_type TEXT,
            file_name TEXT,
            reply_to_id INTEGER,
            forwarded_from_id INTEGER,
            is_forwarded INTEGER DEFAULT 0,
            deleted INTEGER DEFAULT 0,
            delivery_status TEXT DEFAULT 'sent',
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          for (final sql in [
            "ALTER TABLE messages ADD COLUMN media_path TEXT",
            "ALTER TABLE messages ADD COLUMN media_type TEXT",
            "ALTER TABLE messages ADD COLUMN file_name TEXT",
            "ALTER TABLE messages ADD COLUMN reply_to_id INTEGER",
            "ALTER TABLE messages ADD COLUMN forwarded_from_id INTEGER",
            "ALTER TABLE messages ADD COLUMN is_forwarded INTEGER DEFAULT 0",
            "ALTER TABLE messages ADD COLUMN deleted INTEGER DEFAULT 0",
            "ALTER TABLE messages ADD COLUMN delivery_status TEXT DEFAULT 'sent'",
          ]) {
            try {
              await db.execute(sql);
            } catch (_) {}
          }
        }
      },
    );
    return _db!;
  }

  Future<int> getLastMessageId(int roomId) async {
    if (kIsWeb) return _webCursors[roomId] ?? 0;
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
    final current = await getLastMessageId(roomId);
    if (messageId <= current) return;
    if (kIsWeb) {
      _webCursors[roomId] = messageId;
      return;
    }
    final database = await db;
    await database.insert(
      'room_cursors',
      {'room_id': roomId, 'last_message_id': messageId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMessage(Message msg) async {
    if (kIsWeb) {
      final list = _webMessages.putIfAbsent(msg.roomId, () => []);
      final idx = list.indexWhere((m) => m.id == msg.id);
      if (idx >= 0) {
        list[idx] = msg;
      } else {
        list.add(msg);
        list.sort((a, b) => a.id.compareTo(b.id));
      }
      await setLastMessageId(msg.roomId, msg.id);
      return;
    }
    final database = await db;
    await database.insert(
      'messages',
      msg.toCacheMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await setLastMessageId(msg.roomId, msg.id);
  }

  Future<List<Message>> messagesForRoom(int roomId, {int limit = 200}) async {
    if (kIsWeb) {
      final list = _webMessages[roomId] ?? const <Message>[];
      if (list.length <= limit) return List.unmodifiable(list);
      return list.sublist(list.length - limit);
    }
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

  Future<int> estimatedCacheBytes() async {
    if (kIsWeb) {
      var n = 0;
      for (final list in _webMessages.values) {
        n += list.length * 256;
      }
      return n;
    }
    try {
      final database = await db;
      final msgCount = Sqflite.firstIntValue(
            await database.rawQuery('SELECT COUNT(*) FROM messages'),
          ) ??
          0;
      return msgCount * 512;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      _webCursors.clear();
      _webMessages.clear();
      return;
    }
    final database = await db;
    await database.delete('messages');
    await database.delete('room_cursors');
  }

  Future<void> close() async {
    if (kIsWeb) {
      _webCursors.clear();
      _webMessages.clear();
      return;
    }
    await _db?.close();
    _db = null;
  }
}
