import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class ExploreFeedState {
  final List<Post> posts;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  const ExploreFeedState({
    this.posts = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  ExploreFeedState copyWith({
    List<Post>? posts,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) =>
      ExploreFeedState(
        posts: posts ?? this.posts,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class ExploreFeedNotifier extends Notifier<ExploreFeedState> {
  static const _pageSize = 30;

  @override
  ExploreFeedState build() {
    ref.watch(authProvider);
    Future.microtask(refresh);
    return const ExploreFeedState(loading: true);
  }

  ApiService get _api => ref.read(apiProvider);

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final posts = await _api.posts(limit: _pageSize);
      state = ExploreFeedState(
        posts: posts,
        loading: false,
        hasMore: posts.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.posts.isEmpty) return;
    state = state.copyWith(loadingMore: true);
    try {
      final beforeId = state.posts.last.id;
      final more = await _api.posts(beforeId: beforeId, limit: _pageSize);
      state = state.copyWith(
        posts: [...state.posts, ...more],
        loadingMore: false,
        hasMore: more.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }

  void upsert(Post post) {
    final idx = state.posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) {
      state = state.copyWith(posts: [post, ...state.posts]);
    } else {
      final next = [...state.posts];
      next[idx] = post;
      state = state.copyWith(posts: next);
    }
  }

  Future<void> toggleLike(int postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final current = state.posts[idx];
    // Optimistic
    final optimistic = current.copyWith(
      liked: !current.liked,
      likeCount: current.likeCount + (current.liked ? -1 : 1),
    );
    upsert(optimistic);
    try {
      final res = await _api.toggleLike(postId);
      upsert(optimistic.copyWith(liked: res.liked, likeCount: res.likeCount));
    } catch (_) {
      upsert(current); // revert
    }
  }
}

final exploreFeedProvider =
    NotifierProvider<ExploreFeedNotifier, ExploreFeedState>(ExploreFeedNotifier.new);

final postProvider = FutureProvider.autoDispose.family<Post, int>((ref, postId) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).getPost(postId);
});
