import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';
import '../models/post.dart';
import '../models/story.dart';
import '../models/user.dart';

/// Change this to your server (include /api if nginx mounts there).
const String kDefaultApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://127.0.0.1:8000',
);

class ApiService {
  ApiService({String? baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? kDefaultApiBase,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;
  String? _token;

  String get baseUrl => _dio.options.baseUrl;
  String? get token => _token;

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
    final res = await _dio.post(
      '/login',
      data: {'username': username, 'password': password},
    );
    final token = res.data['access_token'] as String;
    await setToken(token);
    return token;
  }

  Future<void> logout() => setToken(null);

  Future<User> me() async {
    final res = await _dio.get('/me');
    return User.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<Room>> listRooms() async {
    final res = await _dio.get('/rooms');
    return (res.data as List)
        .map((e) => Room.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Room> createRoom({
    required String name,
    List<int> memberIds = const [],
    bool isDm = false,
  }) async {
    final res = await _dio.post(
      '/rooms',
      data: {
        'name': name,
        'member_ids': memberIds,
        'is_dm': isDm,
      },
    );
    return Room.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<Message>> roomHistory(int roomId, {int after = 0}) async {
    final res = await _dio.get(
      '/rooms/$roomId/history',
      queryParameters: {'after': after},
    );
    return (res.data as List)
        .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Message> sendMessageRest(int roomId, String content) async {
    final form = FormData.fromMap({'content': content});
    final res = await _dio.post('/rooms/$roomId/messages', data: form);
    return Message.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<Post>> listPosts({int? beforeId, int limit = 30}) async {
    final res = await _dio.get(
      '/posts',
      queryParameters: {
        if (beforeId != null) 'before_id': beforeId,
        'limit': limit,
      },
    );
    return (res.data as List)
        .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<StoryGroup>> listStories() async {
    final res = await _dio.get('/stories');
    return (res.data as List)
        .map((e) => StoryGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  String mediaUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return '';
    final base = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$base/media/$relativePath';
  }
}
