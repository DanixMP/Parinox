import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/local_cache.dart';

final apiProvider = Provider<ApiService>((ref) => ApiService());

final localCacheProvider = Provider<LocalCache>((ref) => LocalCache());

class AuthState {
  final bool isAuthenticated;
  final User? user;

  const AuthState({required this.isAuthenticated, this.user});

  static const loggedOut = AuthState(isAuthenticated: false);
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final api = ref.read(apiProvider);
    await api.loadToken();
    if (api.token == null) return AuthState.loggedOut;
    try {
      final user = await api.me();
      return AuthState(isAuthenticated: true, user: user);
    } catch (_) {
      await api.logout();
      return AuthState.loggedOut;
    }
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiProvider);
      await api.login(username, password);
      final user = await api.me();
      return AuthState(isAuthenticated: true, user: user);
    });
  }

  Future<void> logout() async {
    await ref.read(apiProvider).logout();
    state = const AsyncData(AuthState.loggedOut);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
