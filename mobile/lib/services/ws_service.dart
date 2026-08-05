import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import 'local_cache.dart';

typedef MessageHandler = void Function(Message message);
typedef TypingHandler = void Function(int userId);
typedef ReceiptHandler = void Function(int messageId, String deliveryStatus);
typedef DeletedHandler = void Function(Message message);
typedef PresenceHandler = void Function(int userId, bool online, String? lastSeenAt);
typedef WsTicketFetcher = Future<String> Function();

/// Chat WebSocket with reconnect, last_id persistence, and outbound queue.
class WsService {
  WsService({
    required this.wsBase,
    required this.roomId,
    required this.cache,
    required this.fetchTicket,
    this.onMessage,
    this.onTyping,
    this.onReceipt,
    this.onDeleted,
    this.onPresence,
    this.onConnectionChanged,
  });

  final String wsBase;
  final int roomId;
  final LocalCache cache;
  final WsTicketFetcher fetchTicket;
  final MessageHandler? onMessage;
  final TypingHandler? onTyping;
  final ReceiptHandler? onReceipt;
  final DeletedHandler? onDeleted;
  final PresenceHandler? onPresence;
  final void Function(bool connected)? onConnectionChanged;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _disposed = false;
  bool _connected = false;
  int _backoffSec = 1;
  final List<Map<String, dynamic>> _outbox = [];
  Timer? _reconnectTimer;

  bool get isConnected => _connected;

  Future<void> connect() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();

    final lastId = await cache.getLastMessageId(roomId);
    try {
      final ticket = await fetchTicket();
      final uri = Uri.parse('$wsBase/ws/$roomId').replace(queryParameters: {
        'ticket': ticket,
        'last_id': '$lastId',
      });

      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _connected = true;
      _backoffSec = 1;
      onConnectionChanged?.call(true);
      _flushOutbox();

      _sub = _channel!.stream.listen(
        _onData,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _connected = false;
      onConnectionChanged?.call(false);
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    final Map<String, dynamic> data;
    if (raw is String) {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } else if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else {
      return;
    }

    final type = data['type'] as String? ?? 'message';

    if (type == 'typing') {
      onTyping?.call(data['user_id'] as int);
      return;
    }

    if (type == 'presence') {
      final uid = data['user_id'] as int?;
      if (uid != null) {
        onPresence?.call(
          uid,
          data['online'] == true,
          data['last_seen_at'] as String?,
        );
      }
      return;
    }

    if (type == 'receipts') {
      final mid = data['message_id'] as int?;
      final status = data['delivery_status'] as String?;
      if (mid != null && status != null) {
        onReceipt?.call(mid, status);
      }
      return;
    }

    if (type == 'message_deleted') {
      final msg = Message.fromJson(data);
      cache.upsertMessage(msg);
      onDeleted?.call(msg);
      return;
    }

    final msg = Message.fromJson(data);
    cache.upsertMessage(msg);
    if (!msg.deleted) {
      cache.setLastMessageId(roomId, msg.id);
    }
    onMessage?.call(msg);
  }

  void send({
    String? content,
    String? mediaPath,
    String? mediaType,
    String? fileName,
    int? replyToId,
  }) {
    final payload = <String, dynamic>{
      'type': 'message',
      if (content != null && content.isNotEmpty) 'content': content,
      if (mediaPath != null) 'media_path': mediaPath,
      if (mediaType != null) 'media_type': mediaType,
      if (fileName != null) 'file_name': fileName,
      if (replyToId != null) 'reply_to_id': replyToId,
    };
    _enqueue(payload);
  }

  void sendTyping() {
    if (!_connected || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'typing'}));
  }

  void markDelivered(List<int> messageIds) {
    if (messageIds.isEmpty) return;
    _enqueue({'type': 'delivered', 'message_ids': messageIds});
  }

  void markRead(int upToId) {
    if (upToId <= 0) return;
    _enqueue({'type': 'read', 'up_to_id': upToId});
  }

  void deleteMessage(int messageId) {
    _enqueue({'type': 'delete', 'message_id': messageId});
  }

  void _enqueue(Map<String, dynamic> payload) {
    if (_connected && _channel != null) {
      _channel!.sink.add(jsonEncode(payload));
    } else {
      _outbox.add(payload);
    }
  }

  void _flushOutbox() {
    while (_outbox.isNotEmpty && _connected && _channel != null) {
      final payload = _outbox.removeAt(0);
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void _scheduleReconnect() {
    _connected = false;
    onConnectionChanged?.call(false);
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    if (_disposed) return;
    _reconnectTimer?.cancel();
    final delay = _backoffSec;
    _backoffSec = switch (_backoffSec) {
      1 => 2,
      2 => 5,
      _ => 10,
    };
    _reconnectTimer = Timer(Duration(seconds: delay), connect);
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
  }
}
