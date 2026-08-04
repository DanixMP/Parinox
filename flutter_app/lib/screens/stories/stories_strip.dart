import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/story.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stories_provider.dart';
import '../../services/media_url.dart';
import 'create_story_screen.dart';
import 'story_viewer_screen.dart';

/// Horizontal stories strip for the top of Explore (DESIGN §7).
class StoriesStrip extends ConsumerWidget {
  const StoriesStrip({super.key});

  Future<void> _openViewer(
    BuildContext context,
    WidgetRef ref,
    List<StoryGroup> groups,
    int index,
  ) async {
    if (groups.isEmpty || index < 0 || index >= groups.length) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => StoryViewerScreen(
          groups: groups,
          initialGroupIndex: index,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    ref.read(storiesFeedProvider.notifier).refresh();
  }

  Future<void> _addStory(BuildContext context, WidgetRef ref) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
    );
    if (ok == true) {
      ref.read(storiesFeedProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(storiesFeedProvider);
    final me = ref.watch(authProvider).valueOrNull?.user;
    final api = ref.watch(apiProvider);

    return stories.when(
      loading: () => const SizedBox(
        height: 104,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => SizedBox(
        height: 104,
        child: Center(
          child: TextButton(
            onPressed: () => ref.read(storiesFeedProvider.notifier).refresh(),
            child: const Text('Retry stories'),
          ),
        ),
      ),
      data: (groups) {
        final myIndex = me == null ? -1 : groups.indexWhere((g) => g.userId == me.id);
        final myGroup = myIndex >= 0 ? groups[myIndex] : null;
        final others = <({StoryGroup group, int index})>[
          for (var i = 0; i < groups.length; i++)
            if (me == null || groups[i].userId != me.id) (group: groups[i], index: i),
        ];

        return SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: 1 + others.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i == 0) {
                return _StoryAvatar(
                  label: 'Your story',
                  mediaBase: api.baseUrl,
                  avatarPath: me?.avatarPath,
                  hasUnseen: myGroup?.hasUnseen ?? false,
                  ring: myGroup != null,
                  showAddBadge: true,
                  onTap: () {
                    if (myGroup != null) {
                      _openViewer(context, ref, groups, myIndex);
                    } else {
                      _addStory(context, ref);
                    }
                  },
                  onLongPress: () => _addStory(context, ref),
                );
              }
              final other = others[i - 1];
              return _StoryAvatar(
                label: other.group.displayName.split(' ').first,
                mediaBase: api.baseUrl,
                avatarPath: other.group.avatarPath,
                hasUnseen: other.group.hasUnseen,
                ring: true,
                onTap: () => _openViewer(context, ref, groups, other.index),
              );
            },
          ),
        );
      },
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.label,
    required this.mediaBase,
    required this.hasUnseen,
    required this.ring,
    required this.onTap,
    this.avatarPath,
    this.showAddBadge = false,
    this.onLongPress,
  });

  final String label;
  final String mediaBase;
  final String? avatarPath;
  final bool hasUnseen;
  final bool ring;
  final bool showAddBadge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final url = MediaUrl.resolve(mediaBase, avatarPath);
    final ringColor = hasUnseen
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.all(ring ? 2.5 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ring && hasUnseen
                        ? LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.tertiary,
                            ],
                          )
                        : null,
                    border: ring && !hasUnseen
                        ? Border.all(color: ringColor, width: 2)
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage:
                        url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
                    child: url.isEmpty
                        ? Text(
                            label.isNotEmpty ? label[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                ),
                if (showAddBadge)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.add,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
