import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../models/story.dart';
import 'auth_provider.dart';

final exploreProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).posts();
});

final storiesProvider = FutureProvider.autoDispose<List<StoryGroup>>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).stories();
});
