import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/app_settings.dart';
import '../../models/message.dart';
import '../../models/room.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/livekit_service.dart';
import '../../services/media_url.dart';
import '../../services/ws_service.dart';
import '../../theme/theme.dart';
import '../../widgets/ds/ds_chrome.dart';
import '../../widgets/island_toast.dart';
import '../call/call_screen.dart';
import '../profile/profile_screen.dart';
import 'room_info_screen.dart';
import 'sticker_gif_sheet.dart';
import 'telegram_chat_ui.dart';

class _MentionCandidate {
  const _MentionCandidate({
    required this.handle,
    required this.label,
    required this.kind,
    required this.id,
  });

  final String handle;
  final String label;
  final String kind;
  final int id;
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.roomId,
    required this.title,
    this.isDm = false,
    this.peerUserId,
    this.room,
  });

  final int roomId;
  final String title;
  final bool isDm;
  final int? peerUserId;
  final Room? room;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final List<Message> _messages = [];
  WsService? _ws;
  bool _connected = false;
  bool _uploading = false;
  int? _myId;
  Message? _replyingTo;
  Room? _room;
  List<_MentionCandidate> _mentionSuggestions = [];
  int? _mentionStart;
  bool _peerOnline = false;
  String? _peerLastSeenAt;
  final Map<int, bool> _memberOnline = {};

  bool _selecting = false;
  final Set<int> _selectedIds = {};
  int? _menuMessageId;
  final Map<int, DateTime> _typingUntil = {};
  Timer? _typingSweep;
  bool _preferWifiAutoDl = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    Connectivity().checkConnectivity().then((results) {
      if (!mounted) return;
      final wifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      final mobile = results.contains(ConnectivityResult.mobile);
      setState(() => _preferWifiAutoDl = wifi || !mobile);
    });
  }

  Future<void> _bootstrap() async {
    final api = ref.read(apiProvider);
    final cache = ref.read(localCacheProvider);
    final auth = ref.read(authProvider).valueOrNull;
    _myId = auth?.user?.id;
    _room = widget.room;
    try {
      _room = await api.getRoom(widget.roomId);
      _seedPresenceFromRoom();
    } catch (_) {}

    if (widget.isDm && widget.peerUserId != null) {
      try {
        final profile = await api.userProfile(widget.peerUserId!);
        if (mounted) {
          setState(() {
            _peerOnline = profile.user.isOnline;
            _peerLastSeenAt = profile.user.lastSeenAt;
          });
        }
      } catch (_) {}
    }

    final cached = await cache.messagesForRoom(widget.roomId);
    if (mounted) {
      setState(() {
        _messages
          ..clear()
          ..addAll(cached);
      });
    }

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
            if (!ids.contains(m.id)) {
              _messages.add(m);
            } else {
              final i = _messages.indexWhere((x) => x.id == m.id);
              if (i >= 0) _messages[i] = m;
            }
          }
          _messages.sort((a, b) => a.id.compareTo(b.id));
        });
      }
    } catch (_) {}

    final token = api.token;
    if (token == null) return;

    final typingOn =
        ref.read(settingsProvider).valueOrNull?.typingIndicators ?? true;

    _ws = WsService(
      wsBase: api.wsBase,
      roomId: widget.roomId,
      cache: cache,
      fetchTicket: () => api.wsTicket(widget.roomId),
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
          _typingUntil.remove(msg.senderId);
        });
        _scrollToEnd();
        _ackIncoming(msg);
      },
      onReceipt: (messageId, status) {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == messageId);
          if (idx >= 0) {
            _messages[idx] = _messages[idx].copyWith(deliveryStatus: status);
          }
        });
      },
      onDeleted: (msg) {
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == msg.id);
          if (idx >= 0) _messages[idx] = msg;
        });
      },
      onTyping: typingOn
          ? (userId) {
              if (!mounted || userId == _myId) return;
              setState(() {
                _typingUntil[userId] = DateTime.now().add(const Duration(seconds: 3));
              });
              _typingSweep ??= Timer.periodic(const Duration(seconds: 1), (_) {
                if (!mounted) return;
                final now = DateTime.now();
                final before = _typingUntil.length;
                _typingUntil.removeWhere((_, until) => until.isBefore(now));
                if (_typingUntil.length != before) setState(() {});
                if (_typingUntil.isEmpty) {
                  _typingSweep?.cancel();
                  _typingSweep = null;
                }
              });
            }
          : null,
      onPresence: (userId, online, lastSeenAt) {
        if (!mounted) return;
        setState(() {
          _memberOnline[userId] = online;
          if (widget.peerUserId != null && userId == widget.peerUserId) {
            _peerOnline = online;
            if (!online) _peerLastSeenAt = lastSeenAt ?? _peerLastSeenAt;
          }
        });
      },
      onConnectionChanged: (ok) {
        if (mounted) setState(() => _connected = ok);
        if (ok) _markVisibleAsRead();
      },
    );
    await _ws!.connect();
    _markVisibleAsRead();
  }

  void _seedPresenceFromRoom() {
    final members = _room?.members ?? const <User>[];
    for (final u in members) {
      _memberOnline[u.id] = u.isOnline;
      if (widget.peerUserId != null && u.id == widget.peerUserId) {
        _peerOnline = u.isOnline;
        _peerLastSeenAt = u.lastSeenAt;
      }
    }
  }

  void _openPeerOrRoomProfile() {
    if (widget.isDm && widget.peerUserId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.peerUserId!)),
      );
      return;
    }
    _openRoomInfo();
  }

  String _statusLine() {
    final typingOn =
        ref.read(settingsProvider).valueOrNull?.typingIndicators ?? true;
    if (typingOn && _typingUntil.isNotEmpty) {
      final ids = _typingUntil.keys.toList();
      final names = ids.map((id) {
        final m = _room?.members.where((u) => u.id == id).firstOrNull;
        return m?.displayName ?? 'Someone';
      }).toList();
      if (names.length == 1) return '${names.first} is typing…';
      if (names.length == 2) return '${names[0]} and ${names[1]} are typing…';
      return '${names.length} people are typing…';
    }
    if (!_connected) return 'connecting…';
    if (widget.isDm) {
      return presenceSubtitle(
        peerOnline: _peerOnline,
        lastSeenAt: _peerLastSeenAt,
        wsConnected: true,
        atId: null,
      );
    }
    final onlineCount = _memberOnline.entries
        .where((e) => e.key != _myId && e.value)
        .length;
    final parts = <String>[
      if (_room?.atId != null) _room!.atId!,
      if (onlineCount > 0) '$onlineCount online' else 'offline',
    ];
    return parts.join(' · ');
  }

  void _ackIncoming(Message msg) {
    if (_myId == null || msg.senderId == _myId || msg.deleted) return;
    _ws?.markDelivered([msg.id]);
    _markVisibleAsRead();
  }

  void _markVisibleAsRead() {
    final readReceipts =
        ref.read(settingsProvider).valueOrNull?.readReceipts ?? true;
    if (!readReceipts) return;
    if (_messages.isEmpty || _myId == null) return;
    final maxId = _messages.map((m) => m.id).where((id) => id > 0).fold<int>(0, (a, b) => a > b ? a : b);
    if (maxId > 0) _ws?.markRead(maxId);
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
    if (!(_room?.canPost ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only channel admins can post')),
      );
      return;
    }
    final text = _input.text.trim();
    if (text.isEmpty || _ws == null) return;
    final replyId = _replyingTo?.id;
    _ws!.send(content: text, replyToId: replyId);
    _input.clear();
    setState(() {
      _replyingTo = null;
      _mentionSuggestions = [];
      _mentionStart = null;
    });
    _scrollToEnd();
  }

  List<_MentionCandidate> _allMentionCandidates() {
    final members = _room?.members ?? const <User>[];
    final users = members
        .map(
          (u) => _MentionCandidate(
            handle: u.username,
            label: u.displayName,
            kind: 'user',
            id: u.id,
          ),
        )
        .toList();
    final rooms = ref.read(roomsProvider).valueOrNull ?? const <Room>[];
    final roomCands = rooms
        .where((r) => r.kind != RoomKind.dm && r.publicId != null && r.publicId!.isNotEmpty)
        .map(
          (r) => _MentionCandidate(
            handle: r.publicId!,
            label: r.displayTitle(_myId),
            kind: 'room',
            id: r.id,
          ),
        )
        .toList();
    return [...users, ...roomCands];
  }

  void _onComposerChanged(String value) {
    final typingOn =
        ref.read(settingsProvider).valueOrNull?.typingIndicators ?? true;
    if (typingOn) _ws?.sendTyping();
    final cursor = _input.selection.baseOffset;
    if (cursor < 0) {
      setState(() {
        _mentionSuggestions = [];
        _mentionStart = null;
      });
      return;
    }
    final before = value.substring(0, cursor);
    final match = RegExp(r'(^|[\s])@([A-Za-z0-9_]*)$').firstMatch(before);
    if (match == null) {
      setState(() {
        _mentionSuggestions = [];
        _mentionStart = null;
      });
      return;
    }
    final query = match.group(2)!.toLowerCase();
    final atIndex = before.lastIndexOf('@');
    final cands = _allMentionCandidates()
        .where((c) =>
            c.handle.toLowerCase().startsWith(query) ||
            c.label.toLowerCase().contains(query))
        .take(8)
        .toList();
    setState(() {
      _mentionStart = atIndex;
      _mentionSuggestions = cands;
    });
  }

  void _insertMention(_MentionCandidate cand) {
    final text = _input.text;
    final start = _mentionStart ?? text.length;
    final cursor = _input.selection.baseOffset;
    final end = cursor < 0 ? text.length : cursor;
    final newText = '${text.substring(0, start)}@${cand.handle} ${text.substring(end)}';
    final newCursor = start + cand.handle.length + 2;
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    setState(() {
      _mentionSuggestions = [];
      _mentionStart = null;
    });
  }

  void _openRoomInfo() {
    if (widget.isDm) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoomInfoScreen(roomId: widget.roomId)),
    ).then((_) async {
      try {
        final room = await ref.read(apiProvider).getRoom(widget.roomId);
        if (mounted) setState(() => _room = room);
        ref.invalidate(roomsProvider);
      } catch (_) {}
    });
  }

  Future<void> _pickImageOrVideo({required bool video}) async {
    final file = video
        ? await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3))
        : await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final result = await showMediaCaptionSheet(
      context: context,
      bytes: bytes,
      filename: file.name,
      isVideo: video,
    );
    if (result == null || !result.send || !mounted) return;
    await _uploadAndSend(
      bytes: bytes,
      filename: file.name,
      contentType: file.mimeType,
      caption: result.caption.isEmpty ? null : result.caption,
    );
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    await _uploadAndSend(bytes: bytes, filename: f.name, contentType: f.extension);
  }

  Future<void> _uploadAndSend({
    required List<int> bytes,
    required String filename,
    String? contentType,
    String? caption,
  }) async {
    setState(() => _uploading = true);
    try {
      final uploaded = await ref.read(apiProvider).uploadChatMedia(
            widget.roomId,
            Uint8List.fromList(bytes),
            filename: filename,
            contentType: contentType,
          );
      final text = caption?.trim().isNotEmpty == true
          ? caption!.trim()
          : (_input.text.trim().isEmpty ? null : _input.text.trim());
      _ws?.send(
        content: text,
        mediaPath: uploaded['media_path'] as String?,
        mediaType: uploaded['media_type'] as String?,
        fileName: uploaded['file_name'] as String? ?? filename,
        replyToId: _replyingTo?.id,
      );
      _input.clear();
      setState(() => _replyingTo = null);
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'm4a',
        'aac',
        'wav',
        'ogg',
        'flac',
        'opus',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    await _uploadAndSend(
      bytes: bytes,
      filename: f.name,
      contentType: 'audio/${f.extension ?? 'mpeg'}',
    );
  }

  Future<void> _showAttachSheet() async {
    if (!(_room?.canPost ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only channel admins can post')),
      );
      return;
    }
    final choice = await showDsBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.library_music_outlined),
              title: const Text('Music'),
              onTap: () => Navigator.pop(ctx, 'music'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('Stickers & GIFs'),
              onTap: () => Navigator.pop(ctx, 'stickers'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'image':
        await _pickImageOrVideo(video: false);
      case 'video':
        await _pickImageOrVideo(video: true);
      case 'music':
        await _pickMusic();
      case 'file':
        await _pickAttachment();
      case 'stickers':
        await _openStickerGifPicker();
    }
  }

  Future<void> _openStickerGifPicker() async {
    if (!(_room?.canPost ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only channel admins can post')),
      );
      return;
    }
    final pick = await showStickerGifSheet(context);
    if (pick == null || !mounted) return;
    switch (pick) {
      case StickerPick(:final emoji):
        if (_ws == null) return;
        _ws!.send(content: emoji, replyToId: _replyingTo?.id);
        setState(() => _replyingTo = null);
        _scrollToEnd();
      case GifUrlPick(:final url, :final title):
        await _sendGifFromUrl(url: url, title: title);
    }
  }

  Future<void> _sendGifFromUrl({required String url, required String title}) async {
    setState(() => _uploading = true);
    try {
      final res = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Empty GIF');
      }
      final safeName = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final filename =
          '${safeName.isEmpty ? 'gif' : safeName}_${DateTime.now().millisecondsSinceEpoch}.gif';
      await _uploadAndSend(
        bytes: bytes,
        filename: filename,
        contentType: 'image/gif',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send GIF: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteMessage(Message msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This removes the message for everyone in the chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).deleteMessage(widget.roomId, msg.id);
    } catch (_) {
      _ws?.deleteMessage(msg.id);
    }
  }

  Future<void> _forwardMessage(Message msg) async {
    final rooms = await ref.read(apiProvider).rooms();
    final targets = rooms.where((r) => r.id != widget.roomId).toList();
    if (!mounted) return;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other chats to forward to')),
      );
      return;
    }
    final myId = _myId;
    final Room? picked = await showDialog<Room>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forward to'),
        content: SizedBox(
          width: 360,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: targets.length,
            itemBuilder: (_, i) {
              final r = targets[i];
              return ListTile(
                title: Text(r.displayTitle(myId)),
                subtitle: Text(r.kind.label),
                onTap: () => Navigator.pop(ctx, r),
              );
            },
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await ref.read(apiProvider).forwardMessage(
            fromRoomId: widget.roomId,
            messageId: msg.id,
            toRoomId: picked.id,
          );
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Forwarded to ${picked.displayTitle(myId)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Forward failed: $e')));
    }
  }

  void _copyMessage(Message msg) {
    final text = msg.content?.trim() ?? '';
    if (text.isEmpty) {
      showIslandToast(context, message: 'Nothing to copy', icon: Icons.info_outline_rounded);
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    showIslandToast(context, message: 'Copied');
  }

  void _enterSelection(Message msg) {
    if (msg.deleted) return;
    setState(() {
      _menuMessageId = null;
      _selecting = true;
      _selectedIds
        ..clear()
        ..add(msg.id);
    });
  }

  void _toggleSelected(Message msg) {
    if (msg.deleted) return;
    setState(() {
      _menuMessageId = null;
      if (_selectedIds.contains(msg.id)) {
        _selectedIds.remove(msg.id);
        if (_selectedIds.isEmpty) _selecting = false;
      } else {
        _selectedIds.add(msg.id);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
      _menuMessageId = null;
    });
  }

  void _openMessageMenu(Message msg) {
    if (msg.deleted) return;
    setState(() {
      _menuMessageId = _menuMessageId == msg.id ? null : msg.id;
    });
  }

  void _dismissMessageMenu() {
    if (_menuMessageId == null) return;
    setState(() => _menuMessageId = null);
  }

  void _replyToMessage(Message msg) {
    setState(() {
      _menuMessageId = null;
      _replyingTo = msg;
    });
  }

  Future<void> _replySelected() async {
    final msgs = _selectedMessages.where((m) => !m.deleted).toList();
    if (msgs.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select one message to reply')),
      );
      return;
    }
    setState(() {
      _replyingTo = msgs.first;
      _selecting = false;
      _selectedIds.clear();
    });
  }

  List<Message> get _selectedMessages {
    final byId = {for (final m in _messages) m.id: m};
    return _selectedIds.map((id) => byId[id]).whereType<Message>().toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> _bulkCopy() async {
    final texts = _selectedMessages
        .map((m) => m.content?.trim() ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
    if (texts.isEmpty) {
      showIslandToast(context, message: 'Nothing to copy', icon: Icons.info_outline_rounded);
      return;
    }
    await Clipboard.setData(ClipboardData(text: texts.join('\n')));
    if (!mounted) return;
    showIslandToast(context, message: 'Copied');
    _exitSelection();
  }

  Future<void> _bulkDelete() async {
    final mine = _selectedMessages.where((m) => m.senderId == _myId && !m.deleted).toList();
    if (mine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own messages')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${mine.length} message${mine.length == 1 ? '' : 's'}?'),
        content: const Text('This removes the messages for everyone in the chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    for (final m in mine) {
      try {
        await ref.read(apiProvider).deleteMessage(widget.roomId, m.id);
      } catch (_) {
        _ws?.deleteMessage(m.id);
      }
    }
    if (mounted) _exitSelection();
  }

  Future<void> _bulkForward() async {
    final msgs = _selectedMessages.where((m) => !m.deleted).toList();
    if (msgs.isEmpty) return;
    final rooms = await ref.read(apiProvider).rooms();
    final targets = rooms.where((r) => r.id != widget.roomId).toList();
    if (!mounted) return;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other chats to forward to')),
      );
      return;
    }
    final myId = _myId;
    final Room? picked = await showDialog<Room>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Forward ${msgs.length} message${msgs.length == 1 ? '' : 's'}'),
        content: SizedBox(
          width: 360,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: targets.length,
            itemBuilder: (_, i) {
              final r = targets[i];
              return ListTile(
                title: Text(r.displayTitle(myId)),
                subtitle: Text(r.kind.label),
                onTap: () => Navigator.pop(ctx, r),
              );
            },
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    var ok = 0;
    for (final m in msgs) {
      try {
        await ref.read(apiProvider).forwardMessage(
              fromRoomId: widget.roomId,
              messageId: m.id,
              toRoomId: picked.id,
            );
        ok++;
      } catch (_) {}
    }
    ref.invalidate(roomsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Forwarded $ok to ${picked.displayTitle(myId)}')),
    );
    _exitSelection();
  }

  void _startCall({required bool video}) {
    final livekitRoom = widget.isDm && widget.peerUserId != null && _myId != null
        ? LivekitService.dmCallRoom(_myId!, widget.peerUserId!)
        : LivekitService.chatCallRoom(widget.roomId);
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
    _typingSweep?.cancel();
    _ws?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final mediaBase = api.baseUrl;
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final settings = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final enterToSend = settings.enterToSend;
    final showReadReceipts = settings.readReceipts;
    final title = widget.title;
    final avatarPath = _room?.listAvatarPath(_myId);
    final avatarUrl = MediaUrl.resolve(mediaBase, avatarPath);
    final autoPhotos =
        _preferWifiAutoDl ? settings.autoDlPhotosWifi : settings.autoDlPhotosMobile;
    final autoVideos =
        _preferWifiAutoDl ? settings.autoDlVideosWifi : settings.autoDlVideosMobile;
    final autoFiles =
        _preferWifiAutoDl ? settings.autoDlFilesWifi : settings.autoDlFilesMobile;
    final roomKind = _room?.kind ??
        widget.room?.kind ??
        (widget.isDm ? RoomKind.dm : RoomKind.group);
    final kindAccent = RoomKindStyle.accent(roomKind, scheme);

    return DsScaffold(
      backgroundColor: AppPalette.of(context).chatBackground(context),
      appBar: DsAppBar(
        automaticallyImplyLeading: !_selecting,
        leading: _selecting
            ? IconButton(
                tooltip: 'Cancel',
                onPressed: _exitSelection,
                icon: const Icon(Icons.close),
              )
            : null,
        titleSpacing: 0,
        title: AnimatedSwitcher(
          duration: AppMotion.normal,
          switchInCurve: AppMotion.curve,
          switchOutCurve: AppMotion.curve,
          child: _selecting
              ? Text(
                  '${_selectedIds.length} selected',
                  key: ValueKey(_selectedIds.length),
                )
              : InkWell(
                  key: const ValueKey('chat-title'),
                  onTap: _openPeerOrRoomProfile,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: kindAccent.withValues(alpha: 0.18),
                        backgroundImage: avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Icon(
                                RoomKindStyle.icon(roomKind),
                                size: 18,
                                color: kindAccent,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                RoomKindBadge(kind: roomKind, compact: true),
                              ],
                            ),
                            Text(
                              _statusLine(),
                              style: TextStyle(
                                color: (widget.isDm && _peerOnline) ||
                                        (!widget.isDm && _connected) ||
                                        _typingUntil.isNotEmpty
                                    ? kindAccent
                                    : scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        actions: [
          AnimatedSwitcher(
            duration: AppMotion.normal,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            child: _selecting
                ? Row(
                    key: const ValueKey('sel-actions'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reply',
                        onPressed: _replySelected,
                        icon: const Icon(Icons.reply),
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: _bulkCopy,
                        icon: const Icon(Icons.copy),
                      ),
                      IconButton(
                        tooltip: 'Forward',
                        onPressed: _bulkForward,
                        icon: const Icon(Icons.forward),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: _bulkDelete,
                        icon: Icon(Icons.delete_outline, color: scheme.error),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('chat-actions'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!widget.isDm)
                        IconButton(
                          tooltip: 'Info',
                          onPressed: _openRoomInfo,
                          icon: Icon(Icons.info_outline, color: scheme.onSurface),
                        ),
                      IconButton(
                        tooltip: 'Voice call',
                        onPressed: () => _startCall(video: false),
                        icon: Icon(Icons.call, color: scheme.onSurface),
                      ),
                      IconButton(
                        tooltip: 'Video call',
                        onPressed: () => _startCall(video: true),
                        icon: Icon(Icons.videocam, color: scheme.onSurface),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TelegramMessageList(
              messages: _messages,
              myId: _myId,
              mediaBase: mediaBase,
              scrollController: _scroll,
              onLongPress: (m) {
                if (_selecting) {
                  _toggleSelected(m);
                } else {
                  _enterSelection(m);
                }
              },
              onTap: (m) {
                if (_selecting) {
                  _toggleSelected(m);
                } else {
                  _openMessageMenu(m);
                }
              },
              onDismissMenu: _dismissMessageMenu,
              selectionMode: _selecting,
              selectedIds: _selectedIds,
              menuMessageId: _menuMessageId,
              showReadReceipts: showReadReceipts,
              autoLoadPhotos: autoPhotos,
              autoLoadVideos: autoVideos,
              autoLoadFiles: autoFiles,
              chatTheme: settings.activeChatTheme,
              designSystem: settings.designSystem,
              roomKind: roomKind,
              onReply: (m) {
                _replyToMessage(m);
              },
              onCopy: (m) {
                _dismissMessageMenu();
                _copyMessage(m);
              },
              onForward: (m) {
                _dismissMessageMenu();
                _forwardMessage(m);
              },
              onDelete: (m) {
                _dismissMessageMenu();
                _deleteMessage(m);
              },
            ),
          ),
          if (_mentionSuggestions.isNotEmpty)
            Material(
              color: scheme.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mentionSuggestions.length,
                  itemBuilder: (_, i) {
                    final c = _mentionSuggestions[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        c.kind == 'user' ? Icons.person_outline : Icons.tag,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: Text('@${c.handle}', style: TextStyle(color: scheme.onSurface)),
                      subtitle: Text(c.label, style: TextStyle(color: scheme.onSurfaceVariant)),
                      onTap: () => _insertMention(c),
                    );
                  },
                ),
              ),
            ),
          if (_replyingTo != null)
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              child: Material(
              color: scheme.surfaceContainer,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.reply, size: 18, color: scheme.secondary),
                title: Text(
                  'Replying to ${_replyingTo!.senderDisplayName ?? 'message'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurface),
                ),
                subtitle: Text(
                  _replyingTo!.deleted
                      ? 'Deleted message'
                      : (_replyingTo!.content ??
                          _replyingTo!.fileName ??
                          _replyingTo!.mediaType ??
                          ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                  onPressed: () => setState(() => _replyingTo = null),
                ),
              ),
            ),
            ),
          if (!_selecting)
            (_room?.canPost ?? true)
                ? TelegramComposer(
                    controller: _input,
                    onChanged: _onComposerChanged,
                    onSend: _send,
                    onAttach: _showAttachSheet,
                    onStickers: _openStickerGifPicker,
                    uploading: _uploading,
                    enterToSend: enterToSend,
                    designSystem: settings.designSystem,
                    accentColor: kindAccent,
                  )
                : Material(
                    color: palette.composerFill,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Only admins can send messages in this channel',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
        ],
      ),
    );
  }
}
