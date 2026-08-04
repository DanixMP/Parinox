import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story.dart';
import 'auth_provider.dart';

final storiesProvider =
    FutureProvider.autoDispose<List<StoryGroup>>((ref) async {
  final session = await ref.watch(authProvider.future);
  if (session == null) return [];
  return ref.read(apiServiceProvider).listStories();
});
