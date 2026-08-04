import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story.dart';
import 'auth_provider.dart';

class StoriesNotifier extends AsyncNotifier<List<StoryGroup>> {
  @override
  Future<List<StoryGroup>> build() async {
    ref.watch(authProvider);
    return ref.read(apiProvider).stories();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(apiProvider).stories());
  }

  Future<void> markViewed(int storyId) async {
    try {
      await ref.read(apiProvider).viewStory(storyId);
      final current = state.valueOrNull;
      if (current == null) return;
      final next = current.map((g) {
        final stories = g.stories
            .map((s) => s.id == storyId ? s.copyWith(viewed: true) : s)
            .toList();
        final hasUnseen = stories.any((s) => !s.viewed);
        return g.copyWith(stories: stories, hasUnseen: hasUnseen);
      }).toList();
      // Keep unseen-first ordering
      next.sort((a, b) {
        if (a.hasUnseen != b.hasUnseen) return a.hasUnseen ? -1 : 1;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
      state = AsyncData(next);
    } catch (_) {
      // Non-fatal — feed will reconcile on next refresh
    }
  }
}

final storiesFeedProvider =
    AsyncNotifierProvider<StoriesNotifier, List<StoryGroup>>(StoriesNotifier.new);
