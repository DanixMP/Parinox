import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import 'auth_provider.dart';

final profileProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).valueOrNull?.user;
});
