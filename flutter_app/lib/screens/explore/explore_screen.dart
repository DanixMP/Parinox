import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/explore_provider.dart';
import '../../providers/stories_provider.dart';
import '../../services/media_url.dart';
import '../profile/profile_screen.dart';
import '../stories/stories_strip.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

/// Pinterest-style masonry explore feed + stories strip (DESIGN §7).
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        actions: [
          IconButton(
            tooltip: 'New post',
            onPressed: _createPost,
            icon: const Icon(Icons.add_a_photo_outlined),
          ),
        ],
      ),
      body: feed.loading && feed.posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : feed.error != null && feed.posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load feed'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => ref.read(exploreFeedProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      ref.read(exploreFeedProvider.notifier).refresh(),
                      ref.read(storiesFeedProvider.notifier).refresh(),
                    ]);
                  },
                  child: feed.posts.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            StoriesStrip(),
                            SizedBox(height: 80),
                            Center(child: Text('No posts yet — be the first')),
                          ],
                        )
                      : CustomScrollView(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            const SliverToBoxAdapter(child: StoriesStrip()),
                            SliverPadding(
                              padding: const EdgeInsets.all(6),
                              sliver: SliverMasonryGrid.count(
                                crossAxisCount: 2,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                                childCount: feed.posts.length,
                                itemBuilder: (context, i) {
                                  final post = feed.posts[i];
                                  return _MasonryTile(
                                    post: post,
                                    mediaBase: api.baseUrl,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PostDetailScreen(postId: post.id),
                                        ),
                                      );
                                      // Sync like state after returning
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
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          ],
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createPost,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MasonryTile extends StatelessWidget {
  const _MasonryTile({
    required this.post,
    required this.mediaBase,
    required this.onTap,
    required this.onLike,
    required this.onAuthor,
  });

  final Post post;
  final String mediaBase;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onAuthor;

  @override
  Widget build(BuildContext context) {
    final url = MediaUrl.resolve(mediaBase, post.imagePath);
    // Use stored width/height so tile size is known before image loads (DESIGN §7)
    final ratio = post.aspectRatio.clamp(0.45, 1.8);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: ratio,
              child: url.isEmpty
                  ? const ColoredBox(color: Color(0xFFDDDDDD))
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => ColoredBox(
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onAuthor,
                      child: Text(
                        post.displayName ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            post.liked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: post.liked
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          if (post.likeCount > 0) ...[
                            const SizedBox(width: 2),
                            Text(
                              '${post.likeCount}',
                              style: Theme.of(context).textTheme.labelSmall,
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
    );
  }
}
