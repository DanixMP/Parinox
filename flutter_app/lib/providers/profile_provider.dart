import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'auth_provider.dart';

final profileProvider = FutureProvider.autoDispose<User>((ref) async {
  ref.watch(authProvider);
  return ref.read(apiProvider).me();
});
