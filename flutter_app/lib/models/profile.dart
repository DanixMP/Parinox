import '../models/post.dart';
import 'user.dart';

class Profile {
  final User user;
  final List<Post> posts;
  final int postCount;

  const Profile({
    required this.user,
    this.posts = const [],
    this.postCount = 0,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final user = User(
      id: json['id'] as int,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      bio: (json['bio'] as String?) ?? '',
      avatarPath: json['avatar_path'] as String?,
    );
    final posts = (json['posts'] as List<dynamic>? ?? [])
        .map((e) => Post.fromJson({
              ...e as Map<String, dynamic>,
              'liked': false,
            }))
        .toList();
    return Profile(
      user: user,
      posts: posts,
      postCount: (json['post_count'] as int?) ?? posts.length,
    );
  }
}
