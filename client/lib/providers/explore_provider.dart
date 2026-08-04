import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import 'auth_provider.dart';

final exploreProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  final session = await ref.watch(authProvider.future);
  if (session == null) return [];
  return ref.read(apiServiceProvider).listPosts();
});
