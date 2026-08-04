import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room.dart';
import 'auth_provider.dart';

final roomsProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  // Re-fetch when auth changes
  ref.watch(authProvider);
  return ref.read(apiProvider).rooms();
});
