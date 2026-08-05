import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../models/room.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/media_url.dart';
import '../../theme/theme.dart';
import '../../widgets/ds/ds_chrome.dart';
import '../../widgets/px_ui.dart';
import 'chat_screen.dart';
import 'telegram_chat_ui.dart';

enum _ChatFilter { all, channels, groups, dms }

/// Telegram-style chat list.
class RoomListScreen extends ConsumerStatefulWidget {
  const RoomListScreen({super.key});

  @override
  ConsumerState<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends ConsumerState<RoomListScreen> {
  final _searchCtrl = TextEditingController();
  _ChatFilter _filter = _ChatFilter.all;
  String _query = '';
  bool _searching = false;
  bool _selecting = false;
  final Set<int> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(int roomId) {
    setState(() {
      if (_selectedIds.contains(roomId)) {
        _selectedIds.remove(roomId);
        if (_selectedIds.isEmpty) _selecting = false;
      } else {
        _selectedIds.add(roomId);
        _selecting = true;
      }
    });
  }

  Future<void> _deleteSelected(List<Room> allRooms) async {
    if (_selectedIds.isEmpty) return;
    final selected = allRooms.where((r) => _selectedIds.contains(r.id)).toList();
    final owners = selected
        .where((r) =>
            r.kind != RoomKind.dm &&
            (r.myRole == 'owner' || r.createdBy == ref.read(authProvider).valueOrNull?.user?.id))
        .toList();

    var forEveryone = false;
    if (owners.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete ${selected.length} chat${selected.length == 1 ? '' : 's'}?'),
          content: Text(
            owners.length == selected.length
                ? 'You own some of these. Delete only for you, or permanently for everyone?'
                : 'Remove from your chat list. Owned channels/groups can also be deleted for everyone.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'me'),
              child: const Text('Delete for me'),
            ),
            if (owners.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'everyone'),
                child: const Text('Delete for everyone'),
              ),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      forEveryone = choice == 'everyone';
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete ${selected.length} chat${selected.length == 1 ? '' : 's'}?'),
          content: const Text('They will be removed from your chat list.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final api = ref.read(apiProvider);
    var failed = 0;
    for (final room in selected) {
      try {
        final everyone = forEveryone &&
            room.kind != RoomKind.dm &&
            (room.myRole == 'owner' ||
                room.createdBy == ref.read(authProvider).valueOrNull?.user?.id);
        await api.deleteChat(room.id, forEveryone: everyone);
      } catch (_) {
        failed++;
      }
    }
    _exitSelection();
    ref.invalidate(roomsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Deleted ${selected.length} chat${selected.length == 1 ? '' : 's'}'
              : 'Deleted with $failed error(s)',
        ),
      ),
    );
  }

  List<Room> _apply(List<Room> list) {
    var out = switch (_filter) {
      _ChatFilter.all => list,
      _ChatFilter.channels => list.where((r) => r.kind == RoomKind.channel).toList(),
      _ChatFilter.groups => list.where((r) => r.kind == RoomKind.group).toList(),
      _ChatFilter.dms => list.where((r) => r.kind == RoomKind.dm).toList(),
    };
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return out;
    final myId = ref.read(authProvider).valueOrNull?.user?.id;
    return out.where((r) {
      final title = r.displayTitle(myId).toLowerCase();
      final id = (r.publicId ?? '').toLowerCase();
      final desc = r.description.toLowerCase();
      return title.contains(q) || id.contains(q) || desc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider);
    final myId = ref.watch(authProvider).valueOrNull?.user?.id;
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);

    return DsScaffold(
      backgroundColor: scheme.surface,
      appBar: DsAppBar(
        leading: _selecting
            ? IconButton(
                tooltip: 'Cancel',
                onPressed: _exitSelection,
                icon: const Icon(Icons.close),
              )
            : null,
        title: _selecting
            ? Text('${_selectedIds.length} selected')
            : _searching
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: TextStyle(color: scheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  )
                : const Text('Chats'),
        actions: [
          if (_selecting) ...[
            IconButton(
              tooltip: 'Delete',
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () {
                      final list = ref.read(roomsProvider).valueOrNull ?? const <Room>[];
                      _deleteSelected(list);
                    },
              icon: Icon(Icons.delete_outline, color: scheme.error),
            ),
          ] else ...[
            IconButton(
              tooltip: _searching ? 'Close search' : 'Search',
              onPressed: () {
                setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _searchCtrl.clear();
                    _query = '';
                  }
                });
              },
              icon: Icon(_searching ? Icons.close : Icons.search),
            ),
            IconButton(
              tooltip: 'New chat',
              onPressed: () => _showCreateMenu(context, ref),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ],
      ),
      body: rooms.when(
        data: (list) {
          final filtered = _apply(list);
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No chats yet',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            );
          }
          return RefreshIndicator(
            color: scheme.secondary,
            onRefresh: () async => ref.invalidate(roomsProvider),
            child: Column(
              children: [
                if (!_searching && !_selecting) ...[
                  const SizedBox(height: 8),
                  PxFilterChipBar(
                    labels: const ['All', 'Channels', 'Groups', 'Direct'],
                    selected: _filter.index,
                    onSelected: (i) =>
                        setState(() => _filter = _ChatFilter.values[i]),
                  ),
                  const SizedBox(height: 4),
                ],
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No matches',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 78,
                            color: palette.divider,
                          ),
                          itemBuilder: (context, i) {
                            final room = filtered[i];
                            return _TelegramChatTile(
                              room: room,
                              myId: myId,
                              selecting: _selecting,
                              selected: _selectedIds.contains(room.id),
                              onOpen: () => _openRoom(context, room, ref),
                              onLongPress: () {
                                if (!_selecting) {
                                  setState(() {
                                    _selecting = true;
                                    _selectedIds.add(room.id);
                                  });
                                } else {
                                  _toggleSelect(room.id);
                                }
                              },
                              onToggle: () => _toggleSelect(room.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load: $e', style: TextStyle(color: scheme.error)),
        ),
      ),
      floatingActionButton: _selecting
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: (ref.watch(settingsProvider).valueOrNull?.navBarStyle ==
                            NavBarStyle.floating ||
                        ref.watch(settingsProvider).valueOrNull?.navBarStyle ==
                            NavBarStyle.curved ||
                        ref.watch(settingsProvider).valueOrNull?.navBarStyle ==
                            NavBarStyle.notch)
                    ? 72
                    : 0,
              ),
              child: DsFab(
                heroTag: 'chats-fab',
                onPressed: () => _showCreateMenu(context, ref),
                child: const Icon(Icons.edit),
              ),
            ),
    );
  }

  Future<void> _showCreateMenu(BuildContext context, WidgetRef ref) async {
    final choice = await showDsBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('New channel'),
              onTap: () => Navigator.pop(ctx, 'channel'),
            ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('New group'),
              onTap: () => Navigator.pop(ctx, 'group'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('New message'),
              onTap: () => Navigator.pop(ctx, 'dm'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Join with invite link'),
              onTap: () => Navigator.pop(ctx, 'invite'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'channel':
        await _createChannelDialog(context, ref);
      case 'group':
        await _createGroupDialog(context, ref);
      case 'dm':
        await _startDmDialog(context, ref);
      case 'invite':
        await _joinByInvite(context, ref);
    }
  }

  Future<void> _joinByInvite(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join with invite'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Invite link or code',
            hintText: 'parinox://join/…',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Join')),
        ],
      ),
    );
    final raw = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || raw.isEmpty || !context.mounted) return;
    try {
      final room = await ref.read(apiProvider).joinByInvite(raw);
      ref.invalidate(roomsProvider);
      if (!context.mounted) return;
      _openRoom(context, room, ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Join failed: $e')));
    }
  }

  Future<void> _createChannelDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', prefixText: '# '),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: 'Public ID (optional)',
                prefixText: '@',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    final name = nameCtrl.text.trim().replaceFirst(RegExp(r'^#'), '');
    final description = descCtrl.text.trim();
    final publicId = idCtrl.text.trim().replaceFirst(RegExp(r'^@'), '');
    nameCtrl.dispose();
    descCtrl.dispose();
    idCtrl.dispose();
    if (ok != true || name.isEmpty || !context.mounted) return;
    try {
      final room = await ref.read(apiProvider).createRoom(
            name: name,
            kind: RoomKind.channel,
            description: description,
            publicId: publicId.isEmpty ? null : publicId,
          );
      ref.invalidate(roomsProvider);
      if (!context.mounted) return;
      if (room.inviteShareCode != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Channel created — share invite from chat info'),
            action: SnackBarAction(
              label: 'Copy link',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: room.inviteShareCode!));
              },
            ),
          ),
        );
      }
      _openRoom(context, room, ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _createGroupDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    final users = await ref.read(apiProvider).users();
    if (!context.mounted) {
      nameCtrl.dispose();
      descCtrl.dispose();
      idCtrl.dispose();
      return;
    }
    final myId = ref.read(authProvider).valueOrNull?.user?.id;
    final candidates = users.where((u) => u.id != myId).toList();
    final selected = <int>{};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New group'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Group name'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: idCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Public ID (optional)',
                      prefixText: '@',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  ...candidates.map(
                    (u) => CheckboxListTile(
                      dense: true,
                      value: selected.contains(u.id),
                      title: Text(u.displayName),
                      subtitle: Text('@${u.username}'),
                      onChanged: (v) {
                        setLocal(() {
                          if (v == true) {
                            selected.add(u.id);
                          } else {
                            selected.remove(u.id);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final description = descCtrl.text.trim();
    final publicId = idCtrl.text.trim().replaceFirst(RegExp(r'^@'), '');
    nameCtrl.dispose();
    descCtrl.dispose();
    idCtrl.dispose();
    if (ok != true || name.isEmpty || !context.mounted) return;
    try {
      final room = await ref.read(apiProvider).createRoom(
            name: name,
            kind: RoomKind.group,
            memberIds: selected.toList(),
            description: description,
            publicId: publicId.isEmpty ? null : publicId,
          );
      ref.invalidate(roomsProvider);
      if (!context.mounted) return;
      _openRoom(context, room, ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _startDmDialog(BuildContext context, WidgetRef ref) async {
    final users = await ref.read(apiProvider).users();
    if (!context.mounted) return;
    final myId = ref.read(authProvider).valueOrNull?.user?.id;
    final candidates = users.where((u) => u.id != myId).toList();

    final User? picked = await showDialog<User>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New message'),
        content: SizedBox(
          width: 360,
          child: candidates.isEmpty
              ? const Text('No other users yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (_, i) {
                    final u = candidates[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : '?',
                        ),
                      ),
                      title: Text(u.displayName),
                      subtitle: Text('@${u.username}'),
                      onTap: () => Navigator.pop(ctx, u),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    try {
      final room = await ref.read(apiProvider).openDm(picked.id);
      ref.invalidate(roomsProvider);
      if (!context.mounted) return;
      _openRoom(context, room, ref);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _openRoom(BuildContext context, Room room, WidgetRef ref) {
    final myId = ref.read(authProvider).valueOrNull?.user?.id;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          roomId: room.id,
          title: room.displayTitle(myId),
          isDm: room.kind == RoomKind.dm,
          peerUserId: room.kind == RoomKind.dm
              ? () {
                  final peers = room.members.where((m) => m.id != myId).toList();
                  return peers.isEmpty ? null : peers.first.id;
                }()
              : null,
          room: room,
        ),
      ),
    );
  }
}

class _TelegramChatTile extends ConsumerWidget {
  const _TelegramChatTile({
    required this.room,
    required this.myId,
    required this.selecting,
    required this.selected,
    required this.onOpen,
    required this.onLongPress,
    required this.onToggle,
  });

  final Room room;
  final int? myId;
  final bool selecting;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = room.displayTitle(myId);
    final api = ref.watch(apiProvider);
    final scheme = Theme.of(context).colorScheme;
    final avatarUrl = MediaUrl.resolve(api.baseUrl, room.listAvatarPath(myId));
    final peers = room.kind == RoomKind.dm
        ? room.members.where((m) => m.id != myId).toList()
        : const <User>[];
    final peer = peers.isEmpty ? null : peers.first;
    final last = room.lastMessage;
    String subtitle;
    if (last != null) {
      final preview = last.previewText();
      final who = last.senderId == myId
          ? 'You'
          : (last.senderDisplayName ?? '');
      subtitle = who.isEmpty ? preview : '$who: $preview';
      if (subtitle.trim().isEmpty || subtitle.endsWith(': ')) {
        subtitle = preview.isEmpty ? 'No messages yet' : preview;
      }
    } else {
      subtitle = [
        if (room.kind == RoomKind.dm && peer != null)
          formatLastSeen(peer.lastSeenAt, online: peer.isOnline),
        if (room.atId != null) room.atId!,
        if (room.description.isNotEmpty) room.description,
        if (room.kind != RoomKind.dm) '${room.members.length} members',
      ].where((s) => s.isNotEmpty).join(' · ');
      if (subtitle.isEmpty) subtitle = 'No messages yet';
    }
    final timeLabel =
        last != null && last.createdAt.isNotEmpty ? formatChatListTime(last.createdAt) : '';
    final unread = room.unreadCount;
    final bold = unread > 0;

    final icon = RoomKindStyle.icon(room.kind);
    final kindAccent = RoomKindStyle.accent(room.kind, scheme);
    final stripe = RoomKindStyle.listStripeWidth(room.kind);

    return InkWell(
      onTap: selecting ? onToggle : onOpen,
      onLongPress: onLongPress,
      child: ColoredBox(
        color: selected
            ? kindAccent.withValues(alpha: 0.12)
            : Colors.transparent,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stripe > 0)
                Container(width: stripe, color: kindAccent),
              Expanded(
                child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (selecting) ...[
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? kindAccent : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
              ],
              Stack(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: kindAccent.withValues(alpha: 0.16),
                    backgroundImage:
                        avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Icon(icon, color: kindAccent, size: 26)
                        : null,
                  ),
                  if (peer?.isOnline == true)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                                        color: scheme.onSurface,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              RoomKindBadge(kind: room.kind, compact: true),
                            ],
                          ),
                        ),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: unread > 0
                                      ? kindAccent
                                      : scheme.onSurfaceVariant,
                                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                                ),
                          ),
                        ),
                        if (unread > 0 && !selecting) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: kindAccent,
                              borderRadius: BorderRadius.circular(
                                room.kind == RoomKind.channel ? 6 : 999,
                              ),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
