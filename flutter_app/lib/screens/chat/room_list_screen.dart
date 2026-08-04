import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'chat_screen.dart';

class RoomListScreen extends ConsumerWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    final auth = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: rooms.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No rooms yet. Create one to start chatting.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(roomsProvider),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final room = list[i];
                final subtitle = room.isDm
                    ? room.members
                        .where((m) => m.id != auth?.user?.id)
                        .map((m) => m.displayName)
                        .join(', ')
                    : '${room.members.length} members';
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(room.name.isNotEmpty ? room.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(room.name),
                  subtitle: Text(subtitle),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          roomId: room.id,
                          title: room.name,
                          isDm: room.isDm,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load rooms: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createRoomDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createRoomDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New room'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Room name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      await ref.read(apiProvider).createRoom(name: nameCtrl.text.trim());
      ref.invalidate(roomsProvider);
    }
    nameCtrl.dispose();
  }
}
