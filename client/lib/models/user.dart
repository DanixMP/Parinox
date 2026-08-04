class User {
  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.avatarPath,
    this.createdAt,
  });

  final int id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarPath;
  final String? createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        bio: (json['bio'] as String?) ?? '',
        avatarPath: json['avatar_path'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'bio': bio,
        'avatar_path': avatarPath,
        'created_at': createdAt,
      };
}
