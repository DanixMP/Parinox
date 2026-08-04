import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';
import '../models/post.dart';
import '../models/profile.dart';
import '../models/room.dart';
import '../models/story.dart';
import '../models/user.dart';

/// REST client for Team App API.
///
/// Configure [baseUrl] at build/run time, e.g. `--dart-define=API_BASE=https://yourhost.ir/api`.
class ApiService {
  ApiService({String? baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE',
                    defaultValue: 'http://127.0.0.1:8000',
                  ),
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Dio _dio;
  String? _token;

  String? get token => _token;
  String get baseUrl => _dio.options.baseUrl;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    _applyAuthHeader();
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('access_token');
    } else {
      await prefs.setString('access_token', token);
    }
    _applyAuthHeader();
  }

  void _applyAuthHeader() {
    if (_token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  Future<String> login(String username, String password) async {
    final res = await _dio.post('/login', data: {
      'username': username,
      'password': password,
    });
    final token = res.data['access_token'] as String;
    await setToken(token);
    return token;
  }

  Future<void> logout() => setToken(null);

  Future<User> me() async {
    final res = await _dio.get('/me');
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Profile> myProfile() async {
    final res = await _dio.get('/me/profile');
    return Profile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Profile> userProfile(int userId) async {
    final res = await _dio.get('/users/$userId');
    return Profile.fromJson(res.data as Map<String, dynamic>);
  }

  Future<User> updateMe({String? displayName, String? bio}) async {
    final res = await _dio.patch('/me', data: {
      if (displayName != null) 'display_name': displayName,
      if (bio != null) 'bio': bio,
    });
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<User> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    final res = await _dio.post('/me/avatar', data: form);
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<User> clearAvatar() async {
    final res = await _dio.delete('/me/avatar');
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Room>> rooms() async {
    final res = await _dio.get('/rooms');
    return (res.data as List)
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Room> createRoom({
    required String name,
    List<int> memberIds = const [],
    bool isDm = false,
  }) async {
    final res = await _dio.post('/rooms', data: {
      'name': name,
      'member_ids': memberIds,
      'is_dm': isDm,
    });
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Message>> history(int roomId, {int after = 0}) async {
    final res = await _dio.get('/rooms/$roomId/history', queryParameters: {
      'after': after,
    });
    return (res.data as List)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<User>> users() async {
    final res = await _dio.get('/users');
    return (res.data as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Post>> posts({int? beforeId, int? userId}) async {
    final res = await _dio.get('/posts', queryParameters: {
      if (beforeId != null) 'before_id': beforeId,
      if (userId != null) 'user_id': userId,
    });
    return (res.data as List)
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<StoryGroup>> stories() async {
    final res = await _dio.get('/stories');
    return (res.data as List)
        .map((e) => StoryGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> livekitToken(String room) async {
    final res = await _dio.post('/livekit/token', data: {'room': room});
    return res.data as Map<String, dynamic>;
  }

  /// WebSocket base derived from HTTP base (http→ws, https→wss).
  String get wsBase {
    final http = _dio.options.baseUrl;
    if (http.startsWith('https://')) {
      return 'wss://${http.substring(8).replaceAll(RegExp(r'/$'), '')}';
    }
    if (http.startsWith('http://')) {
      return 'ws://${http.substring(7).replaceAll(RegExp(r'/$'), '')}';
    }
    return http;
  }
}
