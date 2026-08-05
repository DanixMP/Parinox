import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/local_cache.dart';

final apiProvider = Provider<ApiService>((ref) => ApiService());

final localCacheProvider = Provider<LocalCache>((ref) => LocalCache());

class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? errorMessage;

  const AuthState({
    required this.isAuthenticated,
    this.user,
    this.errorMessage,
  });

  static const loggedOut = AuthState(isAuthenticated: false);

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

String authErrorMessage(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    final detail = error.response?.data;
    String? serverDetail;
    if (detail is Map && detail['detail'] != null) {
      serverDetail = detail['detail'].toString();
    }
    if (status == 401) {
      return 'Invalid username or password.';
    }
    if (status == 409) {
      return serverDetail ?? 'Username, email, or phone is already in use.';
    }
    if (status == 422) {
      return serverDetail ?? 'Check your details — email or phone is required.';
    }
    if (status == 429) {
      return 'Too many attempts. Try again shortly.';
    }
    return serverDetail ?? 'Request failed. Try again.';
  }
  return 'Something went wrong. Try again.';
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
    try {
      final api = ref.read(apiProvider);
      await api.login(username, password);
      final user = await api.me();
      state = AsyncData(AuthState(isAuthenticated: true, user: user));
    } catch (e) {
      await ref.read(apiProvider).logout();
      state = AsyncData(AuthState(
        isAuthenticated: false,
        errorMessage: authErrorMessage(e),
      ));
    }
  }

  Future<void> signup({
    required String username,
    required String password,
    required String displayName,
    String? email,
    String? phone,
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiProvider);
      await api.signup(
        username: username,
        password: password,
        displayName: displayName,
        email: email,
        phone: phone,
      );
      final user = await api.me();
      state = AsyncData(AuthState(isAuthenticated: true, user: user));
    } catch (e) {
      await ref.read(apiProvider).logout();
      state = AsyncData(AuthState(
        isAuthenticated: false,
        errorMessage: authErrorMessage(e),
      ));
    }
  }

  Future<void> logout() async {
    await ref.read(apiProvider).logout();
    state = const AsyncData(AuthState.loggedOut);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
