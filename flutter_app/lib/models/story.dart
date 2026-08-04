class StoryItem {
  final int id;
  final String mediaPath;
  final bool isVideo;
  final String createdAt;
  final String expiresAt;
  final bool viewed;

  const StoryItem({
    required this.id,
    required this.mediaPath,
    required this.isVideo,
    required this.createdAt,
    required this.expiresAt,
    required this.viewed,
  });

  factory StoryItem.fromJson(Map<String, dynamic> json) => StoryItem(
        id: json['id'] as int,
        mediaPath: json['media_path'] as String,
        isVideo: (json['is_video'] as bool?) ?? ((json['is_video'] as int?) == 1),
        createdAt: json['created_at'] as String,
        expiresAt: json['expires_at'] as String,
        viewed: (json['viewed'] as bool?) ?? false,
      );
}

class StoryGroup {
  final int userId;
  final String username;
  final String displayName;
  final String? avatarPath;
  final bool hasUnseen;
  final List<StoryItem> stories;

  const StoryGroup({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarPath,
    required this.hasUnseen,
    required this.stories,
  });

  factory StoryGroup.fromJson(Map<String, dynamic> json) => StoryGroup(
        userId: json['user_id'] as int,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        avatarPath: json['avatar_path'] as String?,
        hasUnseen: (json['has_unseen'] as bool?) ?? false,
        stories: (json['stories'] as List<dynamic>? ?? [])
            .map((e) => StoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
