import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/comment.dart';
import '../models/message.dart';
import '../models/post.dart';
import '../models/profile.dart';
import '../models/room.dart';
import '../models/story.dart';
import '../models/user.dart';
import 'media_url.dart';

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
            )) {
    _assertSecureBaseUrl();
  }

  static const _tokenKey = 'access_token';
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final Dio _dio;
  String? _token;

  String? get token => _token;
  String get baseUrl => _dio.options.baseUrl;

  void _assertSecureBaseUrl() {
    if (!kReleaseMode) return;
    final base = _dio.options.baseUrl;
    if (!base.startsWith('https://')) {
      throw StateError(
        'Release builds require HTTPS API_BASE (got: $base). '
        'Pass --dart-define=API_BASE=https://…',
      );
    }
  }

  Future<void> loadToken() async {
    // Prefer secure storage; migrate leftover SharedPreferences tokens once.
    var value = await _secure.read(key: _tokenKey);
    if (value == null || value.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(_tokenKey);
      if (value != null && value.isNotEmpty) {
        await _secure.write(key: _tokenKey, value: value);
        await prefs.remove(_tokenKey);
      }
    }
    _token = value;
    MediaUrl.authToken = _token;
    _applyAuthHeader();
  }

  Future<void> setToken(String? token) async {
    _token = token;
    MediaUrl.authToken = token;
    if (token == null) {
      await _secure.delete(key: _tokenKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } else {
      await _secure.write(key: _tokenKey, value: token);
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

  Future<String> signup({
    required String username,
    required String password,
    required String displayName,
    String? email,
    String? phone,
  }) async {
    final res = await _dio.post('/signup', data: {
      'username': username,
      'password': password,
      'display_name': displayName,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
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

  Future<User> uploadAvatar(Uint8List bytes, {String filename = 'avatar.jpg'}) async {
    final form = FormData.fromMap({
      'avatar': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/me/avatar', data: form);
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<User> clearAvatar() async {
    final res = await _dio.delete('/me/avatar');
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<User> uploadBanner(Uint8List bytes, {String filename = 'banner.jpg'}) async {
    final form = FormData.fromMap({
      'banner': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/me/banner', data: form);
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<User> clearBanner() async {
    final res = await _dio.delete('/me/banner');
    return User.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Room>> rooms({RoomKind? kind}) async {
    final res = await _dio.get('/rooms', queryParameters: {
      if (kind != null) 'kind': kind.apiValue,
    });
    return (res.data as List)
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Room> createRoom({
    required String name,
    RoomKind kind = RoomKind.group,
    List<int> memberIds = const [],
    String description = '',
    String? publicId,
    bool isDm = false,
  }) async {
    final res = await _dio.post('/rooms', data: {
      'name': name,
      'kind': isDm ? RoomKind.dm.apiValue : kind.apiValue,
      'member_ids': memberIds,
      'description': description,
      if (publicId != null && publicId.isNotEmpty) 'public_id': publicId,
      if (isDm) 'is_dm': true,
    });
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Room> getRoom(int roomId) async {
    final res = await _dio.get('/rooms/$roomId');
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Room> updateRoom(
    int roomId, {
    String? name,
    String? description,
    String? publicId,
  }) async {
    final res = await _dio.patch('/rooms/$roomId', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (publicId != null) 'public_id': publicId,
    });
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Room> uploadRoomAvatar(int roomId, Uint8List bytes, {String filename = 'avatar.jpg'}) async {
    final form = FormData.fromMap({
      'avatar': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post('/rooms/$roomId/avatar', data: form);
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Room> clearRoomAvatar(int roomId) async {
    final res = await _dio.delete('/rooms/$roomId/avatar');
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Room> lookupRoom(String publicId) async {
    final pid = publicId.trim().replaceFirst(RegExp(r'^@'), '');
    final res = await _dio.get('/rooms/lookup/$pid');
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Room> joinByInvite(String inviteToken) async {
    var token = inviteToken.trim();
    // Accept pasted share codes / paths
    final joinMatch = RegExp(r'(?:join/|rooms/join/)([A-Za-z0-9_\-]+)').firstMatch(token);
    if (joinMatch != null) {
      token = joinMatch.group(1)!;
    }
    final res = await _dio.post('/rooms/join/$token');
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getRoomInvite(int roomId) async {
    final res = await _dio.get('/rooms/$roomId/invite');
    return res.data as Map<String, dynamic>;
  }

  Future<Room> rotateRoomInvite(int roomId) async {
    final res = await _dio.post('/rooms/$roomId/invite/rotate');
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<String> wsTicket(int roomId) async {
    final res = await _dio.post('/rooms/$roomId/ws-ticket');
    return res.data['ticket'] as String;
  }

  Future<Room> openDm(int userId) async {
    final res = await _dio.post('/dms', data: {'user_id': userId});
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Room> addRoomMembers(int roomId, List<int> userIds) async {
    final res = await _dio.post('/rooms/$roomId/members', data: {
      'user_ids': userIds,
    });
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Room> removeRoomMember(int roomId, int userId) async {
    final res = await _dio.delete('/rooms/$roomId/members/$userId');
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Room> setRoomMemberRole(int roomId, int userId, String role) async {
    final res = await _dio.patch(
      '/rooms/$roomId/members/$userId',
      data: {'role': role},
    );
    return Room.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> leaveRoom(int roomId) async {
    await _dio.delete('/rooms/$roomId/members/me');
  }

  /// Remove chat from my list. [forEveryone] deletes the room (owners only).
  Future<void> deleteChat(int roomId, {bool forEveryone = false}) async {
    await _dio.delete(
      '/rooms/$roomId',
      queryParameters: forEveryone ? {'for_everyone': true} : null,
    );
  }

  Future<List<Message>> history(int roomId, {int after = 0}) async {
    final res = await _dio.get('/rooms/$roomId/history', queryParameters: {
      'after': after,
    });
    return (res.data as List)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> uploadChatMedia(
    int roomId,
    Uint8List bytes, {
    required String filename,
    String? contentType,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post(
      '/rooms/$roomId/media',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Message> deleteMessage(int roomId, int messageId) async {
    final res = await _dio.delete('/rooms/$roomId/messages/$messageId');
    return Message.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Message> forwardMessage({
    required int fromRoomId,
    required int messageId,
    required int toRoomId,
  }) async {
    final res = await _dio.post(
      '/rooms/$fromRoomId/messages/$messageId/forward',
      data: {'to_room_id': toRoomId},
    );
    return Message.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<User>> users() async {
    final res = await _dio.get('/users');
    return (res.data as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Post>> posts({int? beforeId, int? userId, int limit = 30}) async {
    final res = await _dio.get('/posts', queryParameters: {
      if (beforeId != null) 'before_id': beforeId,
      if (userId != null) 'user_id': userId,
      'limit': limit,
    });
    return (res.data as List)
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Post> getPost(int postId) async {
    final res = await _dio.get('/posts/$postId');
    return Post.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Post> createPost({
    required Uint8List imageBytes,
    String caption = '',
    String filename = 'post.jpg',
  }) async {
    final form = FormData.fromMap({
      'caption': caption,
      'image': MultipartFile.fromBytes(imageBytes, filename: filename),
    });
    final res = await _dio.post('/posts', data: form);
    return Post.fromJson(res.data as Map<String, dynamic>);
  }

  Future<({bool liked, int likeCount})> toggleLike(int postId) async {
    final res = await _dio.post('/posts/$postId/like');
    final data = res.data as Map<String, dynamic>;
    return (liked: data['liked'] as bool, likeCount: data['like_count'] as int);
  }

  Future<List<Comment>> comments(int postId) async {
    final res = await _dio.get('/posts/$postId/comments');
    return (res.data as List)
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Comment> addComment(int postId, String content) async {
    final res = await _dio.post('/posts/$postId/comments', data: {'content': content});
    return Comment.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<StoryGroup>> stories() async {
    final res = await _dio.get('/stories');
    return (res.data as List)
        .map((e) => StoryGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StoryItem> createStory(
    Uint8List bytes, {
    bool isVideo = false,
    String? filename,
  }) async {
    final name = filename ?? (isVideo ? 'story.mp4' : 'story.jpg');
    final form = FormData.fromMap({
      'media': MultipartFile.fromBytes(bytes, filename: name),
    });
    final res = await _dio.post('/stories', data: form);
    return StoryItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> viewStory(int storyId) async {
    await _dio.post('/stories/$storyId/view');
  }

  Future<void> deleteStory(int storyId) async {
    await _dio.delete('/stories/$storyId');
  }

  Future<Map<String, dynamic>> livekitToken(String room) async {
    final res = await _dio.post('/livekit/token', data: {'room': room});
    return res.data as Map<String, dynamic>;
  }

  /// WebSocket base derived from HTTP base (http→ws, https→wss).
  /// Strips a trailing `/api` so nginx `/ws/` at host root works.
  String get wsBase {
    var http = _dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    http = http.replaceFirst(RegExp(r'/api$'), '');
    if (http.startsWith('https://')) {
      return 'wss://${http.substring(8)}';
    }
    if (http.startsWith('http://')) {
      return 'ws://${http.substring(7)}';
    }
    return http;
  }
}
