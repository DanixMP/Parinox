import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/app_settings.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/explore_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/stories_provider.dart';
import '../../services/media_url.dart';
import '../../theme/theme.dart';
import '../../widgets/ds/ds_chrome.dart';
import '../profile/profile_screen.dart';
import '../stories/stories_strip.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

/// Pinterest-style masonry explore feed.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      ref.read(exploreFeedProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final created = await Navigator.of(context).push<Post>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (created != null) {
      ref.read(exploreFeedProvider.notifier).upsert(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(exploreFeedProvider);
    final api = ref.watch(apiProvider);
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final crossCount = width >= 1100
        ? 4
        : width >= 700
            ? 3
            : 2;

    return DsScaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: DsAppBar(
        title: Text(
          'Explore',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New post',
            onPressed: _createPost,
            icon: Icon(Icons.add_box_outlined, color: scheme.onSurface),
          ),
        ],
      ),
      body: feed.loading && feed.posts.isEmpty
          ? Center(child: CircularProgressIndicator(color: scheme.secondary))
          : feed.error != null && feed.posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load feed', style: TextStyle(color: scheme.onSurface)),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => ref.read(exploreFeedProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: scheme.secondary,
                  onRefresh: () async {
                    await Future.wait([
                      ref.read(exploreFeedProvider.notifier).refresh(),
                      ref.read(storiesFeedProvider.notifier).refresh(),
                    ]);
                  },
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(child: StoriesStrip()),
                      if (feed.posts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'No pins yet — be the first',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                          sliver: SliverMasonryGrid.count(
                            crossAxisCount: crossCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childCount: feed.posts.length,
                            itemBuilder: (context, i) {
                              final post = feed.posts[i];
                              return _PinCard(
                                post: post,
                                mediaBase: api.baseUrl,
                                shadow: palette.pinShadow,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PostDetailScreen(postId: post.id),
                                    ),
                                  );
                                  ref.read(exploreFeedProvider.notifier).refresh();
                                },
                                onLike: () =>
                                    ref.read(exploreFeedProvider.notifier).toggleLike(post.id),
                                onAuthor: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProfileScreen(userId: post.userId),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      if (feed.loadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: Padding(
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
          heroTag: 'explore-fab',
          onPressed: _createPost,
          child: const Icon(Icons.push_pin_outlined),
        ),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.post,
    required this.mediaBase,
    required this.shadow,
    required this.onTap,
    required this.onLike,
    required this.onAuthor,
  });

  final Post post;
  final String mediaBase;
  final Color shadow;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onAuthor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = MediaUrl.resolve(mediaBase, post.imagePath);
    final ratio = post.aspectRatio.clamp(0.55, 1.75);

    return Material(
      color: scheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(AppRadii.pin),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pin),
            boxShadow: [
              BoxShadow(color: shadow, blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: ratio,
                child: url.isEmpty
                    ? ColoredBox(color: scheme.surfaceContainerHigh)
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            ColoredBox(color: scheme.surfaceContainerHigh),
                        errorWidget: (_, __, ___) => Center(
                          child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
                        ),
                      ),
              ),
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Text(
                    post.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onAuthor,
                        child: Text(
                          post.displayName ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onLike,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              post.liked ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: post.liked ? scheme.error : scheme.onSurfaceVariant,
                            ),
                            if (post.likeCount > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '${post.likeCount}',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
