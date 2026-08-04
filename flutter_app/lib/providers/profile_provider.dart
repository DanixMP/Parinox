import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import 'auth_provider.dart';

final myProfileProvider = FutureProvider.autoDispose<Profile>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).myProfile();
});

final userProfileProvider =
    FutureProvider.autoDispose.family<Profile, int>((ref, userId) async {
  ref.watch(authProvider);
  final me = ref.watch(authProvider).valueOrNull?.user;
  if (me != null && me.id == userId) {
    return ref.read(apiProvider).myProfile();
  }
  return ref.read(apiProvider).userProfile(userId);
});
