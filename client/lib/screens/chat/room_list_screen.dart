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

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: rooms.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No rooms yet'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final room = list[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(room.name.isNotEmpty ? room.name[0].toUpperCase() : '?'),
                ),
                title: Text(room.name),
                subtitle: Text(room.isDm ? 'Direct message' : 'Group'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(roomId: room.id, title: room.name),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Simple group room for Phase 1 — name prompt
          final name = await _promptName(context);
          if (name == null || name.isEmpty) return;
          final api = ref.read(apiServiceProvider);
          await api.createRoom(name: name);
          ref.invalidate(roomsProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<String?> _promptName(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New room'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Room name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
