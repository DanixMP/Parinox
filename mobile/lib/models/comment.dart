class Comment {
  final int id;
  final int postId;
  final int userId;
  final String content;
  final String createdAt;
  final String? displayName;
  final String? username;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.displayName,
    this.username,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as int,
        postId: json['post_id'] as int,
        userId: json['user_id'] as int,
        content: json['content'] as String,
        createdAt: json['created_at'] as String,
        displayName: json['display_name'] as String?,
        username: json['username'] as String?,
      );
}
