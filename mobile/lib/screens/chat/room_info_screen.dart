import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/room.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/media_url.dart';
import '../../widgets/island_back_button.dart';
import '../../widgets/island_toast.dart';
import '../../widgets/zoomable_avatar.dart';
import '../profile/profile_screen.dart';

class RoomInfoScreen extends ConsumerStatefulWidget {
  const RoomInfoScreen({super.key, required this.roomId});

  final int roomId;

  @override
  ConsumerState<RoomInfoScreen> createState() => _RoomInfoScreenState();
}

class _RoomInfoScreenState extends ConsumerState<RoomInfoScreen> {
  Room? _room;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _publicIdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final room = await ref.read(apiProvider).getRoom(widget.roomId);
      if (!mounted) return;
      setState(() {
        _room = room;
        _nameCtrl.text = room.name;
        _descCtrl.text = room.description;
        _publicIdCtrl.text = room.publicId ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final room = await ref.read(apiProvider).updateRoom(
            widget.roomId,
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            publicId: _publicIdCtrl.text.trim().replaceFirst(RegExp(r'^@'), ''),
          );
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      setState(() {
        _room = room;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 90,
    );
    if (file == null) return;
    setState(() => _saving = true);
    try {
      final bytes = await file.readAsBytes();
      final room = await ref.read(apiProvider).uploadRoomAvatar(
            widget.roomId,
            Uint8List.fromList(bytes),
            filename: file.name,
          );
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      setState(() {
        _room = room;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Avatar upload failed: $e')));
    }
  }

  Future<void> _shareInvite(Room room) async {
    try {
      final invite = await ref.read(apiProvider).getRoomInvite(widget.roomId);
      final code = (invite['share_code'] as String?) ??
          room.inviteShareCode ??
          'parinox://join/${invite['invite_token']}';
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Join ${room.displayTitle(ref.read(authProvider).valueOrNull?.user?.id)} on Parinox:\n$code',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get invite: $e')),
      );
    }
  }

  Future<void> _rotateInvite() async {
    setState(() => _saving = true);
    try {
      final room = await ref.read(apiProvider).rotateRoomInvite(widget.roomId);
      if (!mounted) return;
      setState(() {
        _room = room;
        _saving = false;
      });
      showIslandToast(context, message: 'Invite link reset');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    }
  }

  Future<void> _clearAvatar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove photo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final room = await ref.read(apiProvider).clearRoomAvatar(widget.roomId);
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      setState(() {
        _room = room;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _addMembers() async {
    final room = _room;
    if (room == null) return;
    final myId = ref.read(authProvider).valueOrNull?.user?.id;
    final users = await ref.read(apiProvider).users();
    if (!mounted) return;
    final existing = room.members.map((m) => m.id).toSet();
    final candidates = users.where((u) => u.id != myId && !existing.contains(u.id)).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No users left to add')),
      );
      return;
    }
    final selected = <int>{};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add members'),
          content: SizedBox(
            width: 360,
            height: 360,
            child: ListView.builder(
              itemCount: candidates.length,
              itemBuilder: (_, i) {
                final u = candidates[i];
                final checked = selected.contains(u.id);
                return CheckboxListTile(
                  value: checked,
                  title: Text(u.displayName),
                  subtitle: Text('@${u.username}'),
                  onChanged: (v) => setLocal(() {
                    if (v == true) {
                      selected.add(u.id);
                    } else {
                      selected.remove(u.id);
                    }
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: Text('Add (${selected.length})'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || selected.isEmpty || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(apiProvider).addRoomMembers(
            widget.roomId,
            selected.toList(),
          );
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      setState(() {
        _room = updated;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  Future<void> _removeMember(User member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.displayName}?'),
        content: const Text('They will lose access to this chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(apiProvider).removeRoomMember(widget.roomId, member.id);
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      setState(() {
        _room = updated;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Remove failed: $e')));
    }
  }

  Future<void> _setRole(User member, String role) async {
    setState(() => _saving = true);
    try {
      final updated = await ref.read(apiProvider).setRoomMemberRole(
            widget.roomId,
            member.id,
            role,
          );
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      setState(() {
        _room = updated;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role update failed: $e')));
    }
  }

  Future<void> _memberActions(User member) async {
    final room = _room;
    final myId = ref.read(authProvider).valueOrNull?.user?.id;
    if (room == null || myId == null) return;
    final isSelf = member.id == myId;
    final canManage = room.canManageMembers;
    final isOwner = room.myRole == 'owner';
    final targetRole = member.role ?? 'member';
    final myRank = _rank(room.myRole);
    final theirRank = _rank(targetRole);

    if (isSelf) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: member.id)),
      );
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(member.displayName),
              subtitle: Text(_roleLabel(targetRole)),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('View profile'),
              onTap: () => Navigator.pop(ctx, 'profile'),
            ),
            if (isOwner && targetRole == 'member')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Make admin'),
                onTap: () => Navigator.pop(ctx, 'admin'),
              ),
            if (isOwner && targetRole == 'admin')
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Dismiss as admin'),
                onTap: () => Navigator.pop(ctx, 'member'),
              ),
            if (canManage && myRank > theirRank)
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: Theme.of(ctx).colorScheme.error),
                title: Text('Remove from ${room.kind == RoomKind.channel ? 'channel' : 'group'}',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'profile':
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: member.id)),
        );
      case 'admin':
        await _setRole(member, 'admin');
      case 'member':
        await _setRole(member, 'member');
      case 'remove':
        await _removeMember(member);
    }
  }

  Future<void> _leave() async {
    final room = _room;
    if (room == null) return;
    if (room.myRole == 'owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owners must delete the chat instead of leaving')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(room.kind == RoomKind.channel ? 'Leave channel?' : 'Leave group?'),
        content: const Text('You will no longer see this chat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(apiProvider).leaveRoom(widget.roomId);
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Leave failed: $e')));
    }
  }

  Future<void> _deleteForEveryone() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete for everyone?'),
        content: const Text('This permanently deletes the chat for all members.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(apiProvider).deleteChat(widget.roomId, forEveryone: true);
      ref.invalidate(roomsProvider);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _publicIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final room = _room;
    final scheme = Theme.of(context).colorScheme;
    final myId = ref.watch(authProvider).valueOrNull?.user?.id;
    final editable = room != null && room.kind != RoomKind.dm && room.canEditProfile;
    final canManage = room != null && room.kind != RoomKind.dm && room.canManageMembers;

    return Scaffold(
      appBar: AppBar(
        leading: IslandBackButton.maybeOf(context),
        leadingWidth: IslandBackButton.leadingWidthOf(context),
        automaticallyImplyLeading: false,
        title: Text(room?.kind == RoomKind.channel
            ? 'Channel info'
            : room?.kind == RoomKind.group
                ? 'Group info'
                : 'Chat info'),
        actions: [
          if (editable)
            TextButton(
              onPressed: _saving || _loading ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : room == null
                  ? const Center(child: Text('Not found'))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              ZoomableAvatar(
                                heroTag: 'room-avatar-${room.id}',
                                imageUrl: room.avatarPath != null
                                    ? MediaUrl.resolve(api.baseUrl, room.avatarPath)
                                    : null,
                                radius: 48,
                                fallbackLabel: room.name,
                                fallbackIcon: room.kind == RoomKind.channel
                                    ? Icons.tag
                                    : room.kind == RoomKind.group
                                        ? Icons.groups
                                        : Icons.person,
                              ),
                              if (editable)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Material(
                                    color: scheme.primary,
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: _saving
                                          ? null
                                          : () async {
                                              final choice = await showModalBottomSheet<String>(
                                                context: context,
                                                showDragHandle: true,
                                                builder: (ctx) => SafeArea(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      ListTile(
                                                        leading: const Icon(Icons.photo_outlined),
                                                        title: const Text('Change photo'),
                                                        onTap: () => Navigator.pop(ctx, 'change'),
                                                      ),
                                                      if (room.avatarPath != null)
                                                        ListTile(
                                                          leading: Icon(
                                                            Icons.delete_outline,
                                                            color: Theme.of(ctx).colorScheme.error,
                                                          ),
                                                          title: Text(
                                                            'Remove photo',
                                                            style: TextStyle(
                                                              color: Theme.of(ctx).colorScheme.error,
                                                            ),
                                                          ),
                                                          onTap: () => Navigator.pop(ctx, 'clear'),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                              if (!mounted || choice == null) return;
                                              if (choice == 'change') await _pickAvatar();
                                              if (choice == 'clear') await _clearAvatar();
                                            },
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (room.atId != null)
                          Center(
                            child: InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: room.atId!));
                                showIslandToast(context, message: 'Copied ${room.atId}');
                              },
                              child: Text(
                                room.atId!,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        if (room.kind != RoomKind.dm &&
                            (room.myRole == 'owner' || room.myRole == 'admin')) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _saving ? null : () => _shareInvite(room),
                                  icon: const Icon(Icons.link),
                                  label: const Text('Invite link'),
                                ),
                                OutlinedButton(
                                  onPressed: _saving ? null : _rotateInvite,
                                  child: const Text('Reset link'),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (room.myRole == 'owner' || room.myRole == 'admin')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Center(
                              child: Text(
                                'You are ${_roleLabel(room.myRole).toLowerCase()}',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        if (editable) ...[
                          TextField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: room.kind == RoomKind.channel ? 'Channel name' : 'Group name',
                              border: const OutlineInputBorder(),
                            ),
                            enabled: !_saving,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _publicIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Public ID',
                              prefixText: '@',
                              helperText: 'Like Telegram — used for @mentions',
                              border: OutlineInputBorder(),
                            ),
                            enabled: !_saving,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _descCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                            maxLength: 500,
                            enabled: !_saving,
                          ),
                        ] else ...[
                          Text(room.displayTitle(myId), style: Theme.of(context).textTheme.headlineSmall),
                          if (room.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(room.description),
                          ],
                          if (room.kind != RoomKind.dm && !room.canEditProfile)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Only admins can edit this ${room.kind == RoomKind.channel ? 'channel' : 'group'}',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                              ),
                            ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Members (${room.members.length})',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            if (canManage)
                              TextButton.icon(
                                onPressed: _saving ? null : _addMembers,
                                icon: const Icon(Icons.person_add_outlined, size: 18),
                                label: const Text('Add'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...room.members.map(
                          (m) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: m.avatarPath != null
                                  ? CachedNetworkImageProvider(
                                      MediaUrl.resolve(api.baseUrl, m.avatarPath),
                                    )
                                  : null,
                              child: m.avatarPath == null
                                  ? Text(m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '?')
                                  : null,
                            ),
                            title: Row(
                              children: [
                                Flexible(child: Text(m.displayName)),
                                if (m.id == myId) ...[
                                  const SizedBox(width: 6),
                                  Text('(you)', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                                ],
                              ],
                            ),
                            subtitle: Text('@${m.username} · ${_roleLabel(m.role)}'),
                            trailing: room.kind != RoomKind.dm
                                ? IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: _saving ? null : () => _memberActions(m),
                                  )
                                : null,
                            onTap: () => _memberActions(m),
                          ),
                        ),
                        if (room.kind != RoomKind.dm) ...[
                          const SizedBox(height: 24),
                          if (room.myRole != 'owner')
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _leave,
                              icon: const Icon(Icons.logout),
                              label: Text(room.kind == RoomKind.channel ? 'Leave channel' : 'Leave group'),
                            ),
                          if (room.myRole == 'owner') ...[
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                foregroundColor: scheme.error,
                              ),
                              onPressed: _saving ? null : _deleteForEveryone,
                              icon: const Icon(Icons.delete_forever_outlined),
                              label: const Text('Delete for everyone'),
                            ),
                          ],
                        ],
                      ],
                    ),
    );
  }
}

int _rank(String? role) => switch (role) {
      'owner' => 3,
      'admin' => 2,
      _ => 1,
    };

String _roleLabel(String? role) => switch (role) {
      'owner' => 'Owner',
      'admin' => 'Admin',
      _ => 'Member',
    };
