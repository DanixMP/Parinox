class User {
  final int id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarPath;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.avatarPath,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        bio: (json['bio'] as String?) ?? '',
        avatarPath: json['avatar_path'] as String?,
      );
}
