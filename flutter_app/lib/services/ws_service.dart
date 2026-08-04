import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import 'local_cache.dart';

typedef MessageHandler = void Function(Message message);
typedef TypingHandler = void Function(int userId);

/// Chat WebSocket with reconnect, last_id persistence, and outbound queue.
///
/// Contract from DESIGN.md §5:
/// - Persist last_message_id locally
/// - On reconnect always pass persisted last_id
/// - Exponential backoff: 1s → 2s → 5s → 10s cap
/// - Queue outgoing messages while disconnected
class WsService {
  WsService({
    required this.wsBase,
    required this.token,
    required this.roomId,
    required this.cache,
    this.onMessage,
    this.onTyping,
    this.onConnectionChanged,
  });

  final String wsBase;
  final String token;
  final int roomId;
  final LocalCache cache;
  final MessageHandler? onMessage;
  final TypingHandler? onTyping;
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
    final uri = Uri.parse('$wsBase/ws/$roomId').replace(queryParameters: {
      'token': token,
      'last_id': '$lastId',
    });

    try {
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

    if (data['type'] == 'typing') {
      onTyping?.call(data['user_id'] as int);
      return;
    }

    final msg = Message.fromJson(data);
    cache.upsertMessage(msg);
    cache.setLastMessageId(roomId, msg.id);
    onMessage?.call(msg);
  }

  void send(String content) {
    final payload = {'type': 'message', 'content': content};
    if (_connected && _channel != null) {
      _channel!.sink.add(jsonEncode(payload));
    } else {
      _outbox.add(payload);
    }
  }

  void sendTyping() {
    if (!_connected || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'typing'}));
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
