import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/post.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/media_url.dart';
import '../explore/post_detail_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});

  /// Null = current user (own profile with edit/settings).
  final int? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider).valueOrNull?.user;
    final isSelf = userId == null || userId == me?.id;
    final async = isSelf
        ? ref.watch(myProfileProvider)
        : ref.watch(userProfileProvider(userId!));
    final api = ref.watch(apiProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelf ? 'Profile' : 'Member'),
        actions: [
          if (isSelf) ...[
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                if (changed == true) {
                  ref.invalidate(myProfileProvider);
                  ref.invalidate(authProvider);
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'logout') {
                  await ref.read(authProvider.notifier).logout();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'logout', child: Text('Sign out')),
              ],
            ),
          ],
        ],
      ),
      body: async.when(
        data: (profile) => RefreshIndicator(
          onRefresh: () async {
            if (isSelf) {
              ref.invalidate(myProfileProvider);
            } else {
              ref.invalidate(userProfileProvider(userId!));
            }
            await Future<void>.delayed(Duration.zero);
          },
          child: _ProfileBody(
            profile: profile,
            mediaBase: api.baseUrl,
            isSelf: isSelf,
            onEdit: isSelf
                ? () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                    if (changed == true) {
                      ref.invalidate(myProfileProvider);
                    }
                  }
                : null,
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.mediaBase,
    required this.isSelf,
    this.onEdit,
  });

  final Profile profile;
  final String mediaBase;
  final bool isSelf;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final user = profile.user;
    final avatarUrl = MediaUrl.resolve(mediaBase, user.avatarPath);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage:
                      avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 36),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  '@${user.username}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    user.bio,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '${profile.postCount} post${profile.postCount == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (onEdit != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Edit profile'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(height: 24)),
        if (profile.posts.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No posts yet')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(2),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _PostThumb(
                  post: profile.posts[i],
                  mediaBase: mediaBase,
                ),
                childCount: profile.posts.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _PostThumb extends StatelessWidget {
  const _PostThumb({required this.post, required this.mediaBase});

  final Post post;
  final String mediaBase;

  @override
  Widget build(BuildContext context) {
    final url = MediaUrl.resolve(mediaBase, post.imagePath);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)),
        );
      },
      child: url.isEmpty
          ? ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (_, __, ___) => const ColoredBox(
                color: Color(0xFFCCCCCC),
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
    );
  }
}
