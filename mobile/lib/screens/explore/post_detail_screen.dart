import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comment.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/explore_provider.dart';
import '../../services/media_url.dart';
import '../../widgets/island_back_button.dart';
import '../profile/profile_screen.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId, this.initial});

  final int postId;
  final Post? initial;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentCtrl = TextEditingController();
  Post? _post;
  List<Comment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _post = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final post = await api.getPost(widget.postId);
      final comments = await api.comments(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _comments = comments;
        _loading = false;
      });
      ref.read(exploreFeedProvider.notifier).upsert(post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null) return;
    final prev = post;
    setState(() {
      _post = post.copyWith(
        liked: !post.liked,
        likeCount: post.likeCount + (post.liked ? -1 : 1),
      );
    });
    try {
      final res = await ref.read(apiProvider).toggleLike(post.id);
      if (!mounted) return;
      final updated = prev.copyWith(liked: res.liked, likeCount: res.likeCount);
      setState(() => _post = updated);
      ref.read(exploreFeedProvider.notifier).upsert(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() => _post = prev);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _post == null) return;
    setState(() => _sending = true);
    try {
      final c = await ref.read(apiProvider).addComment(_post!.id, text);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, c];
        _post = _post!.copyWith(commentCount: _post!.commentCount + 1);
        _sending = false;
        _commentCtrl.clear();
      });
      ref.read(exploreFeedProvider.notifier).upsert(_post!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final post = _post;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        leading: IslandBackButton.maybeOf(context),
        leadingWidth: IslandBackButton.leadingWidthOf(context),
        automaticallyImplyLeading: false,
      ),
      body: _loading && post == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && post == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : post == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            children: [
                              AspectRatio(
                                aspectRatio: post.aspectRatio.clamp(0.5, 1.6),
                                child: CachedNetworkImage(
                                  imageUrl: MediaUrl.resolve(api.baseUrl, post.imagePath),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => ColoredBox(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProfileScreen(userId: post.userId),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          post.displayName ?? 'Unknown',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _toggleLike,
                                      icon: Icon(
                                        post.liked ? Icons.favorite : Icons.favorite_border,
                                        color: post.liked
                                            ? Theme.of(context).colorScheme.error
                                            : null,
                                      ),
                                    ),
                                    Text('${post.likeCount}'),
                                    const SizedBox(width: 8),
                                  ],
                                ),
                              ),
                              if (post.caption.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: Text(post.caption),
                                ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                                child: Text(
                                  'Comments (${_comments.length})',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              if (_comments.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(child: Text('No comments yet')),
                                )
                              else
                                ..._comments.map(
                                  (c) => ListTile(
                                    dense: true,
                                    title: Text(
                                      c.displayName ?? c.username ?? 'User',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(c.content),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ProfileScreen(userId: c.userId),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _commentCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'Add a comment',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    enabled: !_sending,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _sendComment(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: _sending ? null : _sendComment,
                                  icon: const Icon(Icons.send),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}
