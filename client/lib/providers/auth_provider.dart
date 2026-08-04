import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/local_cache.dart';
import '../services/ws_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  final api = ApiService();
  ref.onDispose(() {});
  return api;
});

final localCacheProvider = Provider<LocalCache>((ref) => LocalCache());

final wsServiceProvider = Provider<WsService>((ref) {
  final api = ref.watch(apiServiceProvider);
  final cache = ref.watch(localCacheProvider);
  return WsService(apiBase: api.baseUrl, localCache: cache);
});

class AuthSession {
  const AuthSession({required this.token, required this.user});
  final String token;
  final User user;
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthSession?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final api = ref.read(apiServiceProvider);
    await api.loadToken();
    if (api.token == null) return null;
    try {
      final user = await api.me();
      return AuthSession(token: api.token!, user: user);
    } catch (_) {
      await api.logout();
      return null;
    }
  }

  Future<void> login(String username, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      final token = await api.login(username, password);
      final user = await api.me();
      return AuthSession(token: token, user: user);
    });
  }

  Future<void> logout() async {
    final api = ref.read(apiServiceProvider);
    final ws = ref.read(wsServiceProvider);
    await ws.disconnect(manual: true);
    await api.logout();
    state = const AsyncData(null);
  }
}
