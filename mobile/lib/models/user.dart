class User {
  final int id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarPath;
  final String? bannerPath;
  final String? email;
  final String? phone;
  final bool isOnline;
  final String? lastSeenAt;
  /// Room membership role when listed inside a room (`owner` / `admin` / `member`).
  final String? role;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.avatarPath,
    this.bannerPath,
    this.email,
    this.phone,
    this.isOnline = false,
    this.lastSeenAt,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        bio: (json['bio'] as String?) ?? '',
        avatarPath: json['avatar_path'] as String?,
        bannerPath: json['banner_path'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        isOnline: json['is_online'] == true,
        lastSeenAt: json['last_seen_at'] as String?,
        role: json['role'] as String?,
      );

  User copyWith({
    bool? isOnline,
    String? lastSeenAt,
    String? avatarPath,
    String? bannerPath,
    String? displayName,
    String? bio,
    String? role,
  }) =>
      User(
        id: id,
        username: username,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        avatarPath: avatarPath ?? this.avatarPath,
        bannerPath: bannerPath ?? this.bannerPath,
        email: email,
        phone: phone,
        isOnline: isOnline ?? this.isOnline,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        role: role ?? this.role,
      );

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || role == 'owner';
}

String formatLastSeen(String? iso, {bool online = false}) {
  if (online) return 'online';
  if (iso == null || iso.isEmpty) return 'last seen recently';
  DateTime? dt;
  try {
    dt = DateTime.parse(iso.endsWith('Z') ? iso : '${iso}Z').toLocal();
  } catch (_) {
    return 'last seen recently';
  }
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'last seen just now';
  if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes} min ago';
  if (diff.inHours < 24 && now.day == dt.day) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'last seen at $h:$m';
  }
  if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return 'last seen ${days[dt.weekday - 1]}';
  }
  return 'last seen ${dt.day}/${dt.month}/${dt.year}';
}
