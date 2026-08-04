class StoryItem {
  const StoryItem({
    required this.id,
    required this.mediaPath,
    required this.isVideo,
    required this.viewed,
    this.createdAt,
    this.expiresAt,
  });

  final int id;
  final String mediaPath;
  final bool isVideo;
  final bool viewed;
  final String? createdAt;
  final String? expiresAt;

  factory StoryItem.fromJson(Map<String, dynamic> json) => StoryItem(
        id: json['id'] as int,
        mediaPath: json['media_path'] as String,
        isVideo: json['is_video'] == true || json['is_video'] == 1,
        viewed: json['viewed'] == true || json['viewed'] == 1,
        createdAt: json['created_at'] as String?,
        expiresAt: json['expires_at'] as String?,
      );
}

class StoryGroup {
  const StoryGroup({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.hasUnseen,
    required this.stories,
    this.avatarPath,
  });

  final int userId;
  final String username;
  final String displayName;
  final String? avatarPath;
  final bool hasUnseen;
  final List<StoryItem> stories;

  factory StoryGroup.fromJson(Map<String, dynamic> json) => StoryGroup(
        userId: json['user_id'] as int,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        avatarPath: json['avatar_path'] as String?,
        hasUnseen: json['has_unseen'] == true,
        stories: (json['stories'] as List<dynamic>)
            .map((e) => StoryItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
