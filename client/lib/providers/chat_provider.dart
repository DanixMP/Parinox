import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import 'auth_provider.dart';

final roomsProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  final session = await ref.watch(authProvider.future);
  if (session == null) return [];
  final api = ref.read(apiServiceProvider);
  return api.listRooms();
});

class ChatState {
  const ChatState({
    this.messages = const [],
    this.connected = false,
    this.typingUser,
  });

  final List<Message> messages;
  final bool connected;
  final String? typingUser;

  ChatState copyWith({
    List<Message>? messages,
    bool? connected,
    String? typingUser,
    bool clearTyping = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        connected: connected ?? this.connected,
        typingUser: clearTyping ? null : (typingUser ?? this.typingUser),
      );
}

final chatProvider =
    NotifierProvider.family<ChatNotifier, ChatState, int>(ChatNotifier.new);

class ChatNotifier extends FamilyNotifier<ChatState, int> {
  @override
  ChatState build(int roomId) {
    _bootstrap(roomId);
    ref.onDispose(() {
      ref.read(wsServiceProvider).disconnect(manual: true);
    });
    return const ChatState();
  }

  Future<void> _bootstrap(int roomId) async {
    final cache = ref.read(localCacheProvider);
    final cached = await cache.messagesForRoom(roomId);
    if (cached.isNotEmpty) {
      state = state.copyWith(messages: cached);
    }

    final session = await ref.read(authProvider.future);
    if (session == null) return;

    final api = ref.read(apiServiceProvider);
    final lastId = await cache.getLastMessageId(roomId);
    try {
      final history = await api.roomHistory(roomId, after: lastId);
      for (final m in history) {
        await cache.upsertMessage(m);
      }
      final all = await cache.messagesForRoom(roomId);
      state = state.copyWith(messages: all);
    } catch (_) {
      // offline — keep cache
    }

    final ws = ref.read(wsServiceProvider);
    ws.onMessage = (msg) {
      if (msg.roomId != roomId) return;
      final existing = [...state.messages];
      if (existing.any((m) => m.id == msg.id)) return;
      existing.add(msg);
      state = state.copyWith(messages: existing);
    };
    ws.onEvent = (event) {
      if (event['type'] == 'typing') {
        state = state.copyWith(typingUser: event['username'] as String?);
      } else if (event['type'] == 'resync_complete') {
        // no-op; messages already applied via onMessage
      }
    };
    ws.onConnectionChanged = (connected) {
      state = state.copyWith(connected: connected);
      if (connected) {
        _flushOutbox(roomId);
      }
    };
    await ws.connect(roomId: roomId, token: session.token);
  }

  Future<void> send(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;
    final roomId = arg;
    final ws = ref.read(wsServiceProvider);
    final cache = ref.read(localCacheProvider);

    if (!ws.isConnected) {
      await cache.enqueueOutbox(roomId, text);
      final pending = Message(
        id: -DateTime.now().millisecondsSinceEpoch,
        roomId: roomId,
        senderId: (await ref.read(authProvider.future))!.user.id,
        content: text,
        localStatus: 'sending',
        createdAt: DateTime.now().toIso8601String(),
      );
      state = state.copyWith(messages: [...state.messages, pending]);
      return;
    }

    ws.sendMessage(content: text);
  }

  Future<void> _flushOutbox(int roomId) async {
    final cache = ref.read(localCacheProvider);
    final ws = ref.read(wsServiceProvider);
    final pending = await cache.pendingOutbox(roomId);
    for (final row in pending) {
      ws.sendMessage(content: row['content'] as String);
      await cache.clearOutboxItem(row['local_id'] as int);
    }
    // Drop local optimistic "sending" placeholders; server acks replace them.
    state = state.copyWith(
      messages: state.messages.where((m) => m.id > 0).toList(),
    );
  }
}
