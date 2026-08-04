import 'user.dart';

class Room {
  final int id;
  final String name;
  final bool isDm;
  final String? createdAt;
  final List<User> members;

  const Room({
    required this.id,
    required this.name,
    required this.isDm,
    this.createdAt,
    this.members = const [],
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final rawDm = json['is_dm'];
    final isDm = rawDm is bool ? rawDm : (rawDm == 1 || rawDm == '1');
    return Room(
      id: json['id'] as int,
      name: json['name'] as String,
      isDm: isDm,
      createdAt: json['created_at'] as String?,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
