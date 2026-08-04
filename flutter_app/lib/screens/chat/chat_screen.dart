import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/message.dart';
import '../../providers/auth_provider.dart';
import '../../services/livekit_service.dart';
import '../../services/ws_service.dart';
import '../call/call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.roomId,
    required this.title,
    this.isDm = false,
  });

  final int roomId;
  final String title;
  final bool isDm;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Message> _messages = [];
  WsService? _ws;
  bool _connected = false;
  int? _myId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final api = ref.read(apiProvider);
    final cache = ref.read(localCacheProvider);
    final auth = ref.read(authProvider).valueOrNull;
    _myId = auth?.user?.id;

    // Show cached messages immediately
    final cached = await cache.messagesForRoom(widget.roomId);
    if (mounted) {
      setState(() {
        _messages
          ..clear()
          ..addAll(cached);
      });
    }

    // REST fallback / catch-up
    final after = await cache.getLastMessageId(widget.roomId);
    try {
      final hist = await api.history(widget.roomId, after: after);
      for (final m in hist) {
        await cache.upsertMessage(m);
      }
      if (hist.isNotEmpty && mounted) {
        setState(() {
          final ids = _messages.map((m) => m.id).toSet();
          for (final m in hist) {
            if (!ids.contains(m.id)) _messages.add(m);
          }
          _messages.sort((a, b) => a.id.compareTo(b.id));
        });
      }
    } catch (_) {
      // offline — cache is enough for now
    }

    final token = api.token;
    if (token == null) return;

    _ws = WsService(
      wsBase: api.wsBase,
      token: token,
      roomId: widget.roomId,
      cache: cache,
      onMessage: (msg) {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx >= 0) {
            _messages[idx] = msg;
          } else {
            _messages.add(msg);
          }
          _messages.sort((a, b) => a.id.compareTo(b.id));
        });
        _scrollToEnd();
      },
      onConnectionChanged: (ok) {
        if (mounted) setState(() => _connected = ok);
      },
    );
    await _ws!.connect();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || _ws == null) return;

    // Optimistic local bubble while disconnected / until server ack
    if (!_connected && _myId != null) {
      setState(() {
        _messages.add(Message(
          id: -DateTime.now().millisecondsSinceEpoch,
          roomId: widget.roomId,
          senderId: _myId!,
          content: text,
          createdAt: DateTime.now().toIso8601String(),
          pending: true,
        ));
      });
    }

    _ws!.send(text);
    _input.clear();
    _scrollToEnd();
  }

  void _startCall({required bool video}) {
    final livekitRoom = LivekitService.chatCallRoom(widget.roomId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          livekitRoom: livekitRoom,
          title: video ? 'Video · ${widget.title}' : 'Voice · ${widget.title}',
          video: video,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ws?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              _connected ? 'Connected' : 'Reconnecting…',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Voice call',
            onPressed: () => _startCall(video: false),
            icon: const Icon(Icons.call),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () => _startCall(video: true),
            icon: const Icon(Icons.videocam),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final m = _messages[i];
                final mine = m.senderId == _myId;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: mine
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!mine && m.senderDisplayName != null)
                          Text(
                            m.senderDisplayName!,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        Text(m.content ?? ''),
                        if (m.pending)
                          Text(
                            'Sending…',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      onChanged: (_) => _ws?.sendTyping(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
