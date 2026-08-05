import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/post.dart';
import '../../models/profile.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/livekit_service.dart';
import '../../services/media_url.dart';
import '../../widgets/ds/ds_chrome.dart';
import '../../widgets/island_back_button.dart';
import '../../widgets/zoomable_avatar.dart';
import '../call/call_screen.dart';
import '../chat/chat_screen.dart';
import '../explore/post_detail_screen.dart';
import '../settings/settings_screen.dart';
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

    final body = async.when(
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
          myId: me?.id,
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
          onOpenSettings: isSelf
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }
              : null,
          onMessage: !isSelf
              ? () => _openDm(context, ref, profile, me?.id)
              : null,
          onVoiceCall: !isSelf && me != null
              ? () => _startCall(
                    context,
                    meId: me.id,
                    peer: profile.user,
                    video: false,
                  )
              : null,
          onVideoCall: !isSelf && me != null
              ? () => _startCall(
                    context,
                    meId: me.id,
                    peer: profile.user,
                    video: true,
                  )
              : null,
          onBlock: !isSelf ? () => _confirmBlock(context, profile.user) : null,
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load profile: $e')),
    );

    // Other members: no top "Member" bar — island back only.
    if (!isSelf) {
      return DsScaffold(
        body: IslandBackOverlay(child: body),
      );
    }

    return DsScaffold(
      appBar: DsAppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
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
              if (value == 'settings') {
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (value == 'logout') {
                await ref.read(authProvider.notifier).logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _openDm(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
    int? myId,
  ) async {
    try {
      final room = await ref.read(apiProvider).openDm(profile.user.id);
      ref.invalidate(roomsProvider);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            roomId: room.id,
            title: room.displayTitle(myId),
            isDm: true,
            peerUserId: profile.user.id,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    }
  }

  void _startCall(
    BuildContext context, {
    required int meId,
    required User peer,
    required bool video,
  }) {
    final room = LivekitService.dmCallRoom(meId, peer.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          livekitRoom: room,
          title: video ? 'Video · ${peer.displayName}' : 'Voice · ${peer.displayName}',
          video: video,
        ),
      ),
    );
  }

  Future<void> _confirmBlock(BuildContext context, User user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${user.displayName}?'),
        content: const Text(
          'They won’t be able to message you. You can manage blocked users in Privacy settings.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.displayName} blocked')),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.mediaBase,
    required this.isSelf,
    this.myId,
    this.onEdit,
    this.onMessage,
    this.onVoiceCall,
    this.onVideoCall,
    this.onBlock,
    this.onOpenSettings,
  });

  final Profile profile;
  final String mediaBase;
  final bool isSelf;
  final int? myId;
  final VoidCallback? onEdit;
  final VoidCallback? onMessage;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onBlock;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final user = profile.user;
    final avatarUrl = MediaUrl.resolve(mediaBase, user.avatarPath);
    final bannerUrl = MediaUrl.resolve(mediaBase, user.bannerPath);
    final cs = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Space for floating island back when viewing another member.
        if (!isSelf) const SliverToBoxAdapter(child: SizedBox(height: 48)),
        SliverToBoxAdapter(
          child: Column(
            children: [
              SizedBox(
                height: 210,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 140,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primary.withValues(alpha: 0.9),
                              cs.secondary.withValues(alpha: 0.55),
                              cs.tertiary.withValues(alpha: 0.35),
                            ],
                          ),
                          image: bannerUrl.isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(bannerUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                cs.shadow.withValues(alpha: 0.05),
                                cs.shadow.withValues(alpha: 0.28),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: scaffoldBg,
                            shape: BoxShape.circle,
                          ),
                          child: ZoomableAvatar(
                            heroTag: 'profile-avatar-${user.id}',
                            imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                            radius: 52,
                            fallbackLabel: user.displayName,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  children: [
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    Text(
                      '@${user.username}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatLastSeen(user.lastSeenAt, online: user.isOnline),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: user.isOnline ? cs.secondary : cs.onSurfaceVariant,
                            fontWeight: user.isOnline ? FontWeight.w600 : FontWeight.w400,
                          ),
                    ),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        user.bio,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${profile.postCount}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'posts',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (!isSelf) ...[
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ActionOrb(
                            icon: Icons.chat_bubble_rounded,
                            label: 'Message',
                            onTap: onMessage,
                          ),
                          _ActionOrb(
                            icon: Icons.call_rounded,
                            label: 'Call',
                            onTap: onVoiceCall,
                          ),
                          _ActionOrb(
                            icon: Icons.videocam_rounded,
                            label: 'Video',
                            onTap: onVideoCall,
                          ),
                          _ActionOrb(
                            icon: Icons.block_rounded,
                            label: 'Block',
                            onTap: onBlock,
                          ),
                        ],
                      ),
                    ],
                    if (onEdit != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit profile'),
                        ),
                      ),
                    ],
                    if (onOpenSettings != null) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Settings'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (profile.posts.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No posts yet')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _PostThumb(
                    post: profile.posts[i],
                    mediaBase: mediaBase,
                  ),
                ),
                childCount: profile.posts.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionOrb extends StatelessWidget {
  const _ActionOrb({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(icon, color: cs.onSurface, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
            ),
          ],
        ),
      ),
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
              errorWidget: (_, __, ___) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}
