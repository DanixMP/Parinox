class Post {
  final int id;
  final int userId;
  final String caption;
  final String imagePath;
  final int width;
  final int height;
  final String createdAt;
  final String? displayName;
  final bool liked;
  final int likeCount;
  final int commentCount;

  const Post({
    required this.id,
    required this.userId,
    required this.caption,
    required this.imagePath,
    required this.width,
    required this.height,
    required this.createdAt,
    this.displayName,
    this.liked = false,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        caption: (json['caption'] as String?) ?? '',
        imagePath: json['image_path'] as String,
        width: json['width'] as int,
        height: json['height'] as int,
        createdAt: json['created_at'] as String,
        displayName: json['display_name'] as String?,
        liked: (json['liked'] as bool?) ?? false,
        likeCount: (json['like_count'] as int?) ?? 0,
        commentCount: (json['comment_count'] as int?) ?? 0,
      );
}
