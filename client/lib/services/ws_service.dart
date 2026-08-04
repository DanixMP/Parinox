import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/message.dart';
import 'local_cache.dart';

typedef MessageHandler = void Function(Message message);
typedef EventHandler = void Function(Map<String, dynamic> event);

/// Chat WebSocket with reconnect + last_id persistence (DESIGN.md §5).
class WsService {
  WsService({
    required this.apiBase,
    required this.localCache,
  });

  final String apiBase;
  final LocalCache localCache;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _backoffSec = 1;
  bool _manualClose = false;
  int? _roomId;
  String? _token;

  MessageHandler? onMessage;
  EventHandler? onEvent;
  void Function(bool connected)? onConnectionChanged;

  bool get isConnected => _channel != null;

  Uri _wsUri(int roomId, String token, int lastId) {
    final http = Uri.parse(apiBase);
    final scheme = http.scheme == 'https' ? 'wss' : 'ws';
    // Strip trailing /api — WS is mounted at /ws/{room_id}
    final host = http.host;
    final port = http.hasPort ? http.port : null;
    final path = '/ws/$roomId';
    return Uri(
      scheme: scheme,
      host: host,
      port: port,
      path: path,
      queryParameters: {
        'token': token,
        'last_id': '$lastId',
      },
    );
  }

  Future<void> connect({
    required int roomId,
    required String token,
  }) async {
    await disconnect(manual: true);
    _manualClose = false;
    _roomId = roomId;
    _token = token;
    await _open();
  }

  Future<void> _open() async {
    final roomId = _roomId;
    final token = _token;
    if (roomId == null || token == null) return;

    final lastId = await localCache.getLastMessageId(roomId);
    final uri = _wsUri(roomId, token, lastId);

    try {
      _channel = WebSocketChannel.connect(uri);
      onConnectionChanged?.call(true);
      _backoffSec = 1;

      _sub = _channel!.stream.listen(
        _onData,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      onConnectionChanged?.call(false);
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final data = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      final type = data['type'] as String? ?? '';

      if (type == 'message') {
        final msg = Message.fromJson(
          Map<String, dynamic>.from(data['message'] as Map),
        );
        localCache.upsertMessage(msg);
        localCache.setLastMessageId(msg.roomId, msg.id);
        onMessage?.call(msg);
        return;
      }

      onEvent?.call(data);
    } catch (_) {
      // ignore malformed frames
    }
  }

  void _scheduleReconnect() {
    onConnectionChanged?.call(false);
    _channel = null;
    _sub?.cancel();
    _sub = null;
    if (_manualClose) return;

    _reconnectTimer?.cancel();
    final delay = _backoffSec;
    _backoffSec = (delay * 2).clamp(1, 10);
    // Cap progression: 1 → 2 → 5 → 10 (design §5)
    if (delay == 2) {
      _backoffSec = 5;
    } else if (delay >= 5) {
      _backoffSec = 10;
    }

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      _open();
    });
  }

  void sendMessage({String? content, String? imagePath}) {
    final payload = <String, dynamic>{
      'type': 'message',
      if (content != null) 'content': content,
      if (imagePath != null) 'image_path': imagePath,
    };
    _channel?.sink.add(jsonEncode(payload));
  }

  void sendTyping() {
    _channel?.sink.add(jsonEncode({'type': 'typing'}));
  }

  void ping() {
    _channel?.sink.add(jsonEncode({'type': 'ping'}));
  }

  Future<void> disconnect({bool manual = false}) async {
    _manualClose = manual;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    onConnectionChanged?.call(false);
  }
}
