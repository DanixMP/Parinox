import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/story.dart';
import 'auth_provider.dart';

final storiesFeedProvider = FutureProvider.autoDispose<List<StoryGroup>>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).stories();
});
