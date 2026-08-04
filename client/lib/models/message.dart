class Message {
  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.content,
    this.imagePath,
    this.createdAt,
    this.senderUsername,
    this.senderDisplayName,
    this.localStatus,
  });

  final int id;
  final int roomId;
  final int senderId;
  final String? content;
  final String? imagePath;
  final String? createdAt;
  final String? senderUsername;
  final String? senderDisplayName;

  /// Local-only: null | sending | failed
  final String? localStatus;

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as int,
        roomId: json['room_id'] as int,
        senderId: json['sender_id'] as int,
        content: json['content'] as String?,
        imagePath: json['image_path'] as String?,
        createdAt: json['created_at'] as String?,
        senderUsername: json['sender_username'] as String?,
        senderDisplayName: json['sender_display_name'] as String?,
        localStatus: json['local_status'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'content': content,
        'image_path': imagePath,
        'created_at': createdAt,
        'sender_username': senderUsername,
        'sender_display_name': senderDisplayName,
        'local_status': localStatus,
      };

  Message copyWith({String? localStatus, int? id}) => Message(
        id: id ?? this.id,
        roomId: roomId,
        senderId: senderId,
        content: content,
        imagePath: imagePath,
        createdAt: createdAt,
        senderUsername: senderUsername,
        senderDisplayName: senderDisplayName,
        localStatus: localStatus ?? this.localStatus,
      );
}

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.isDm,
    this.createdAt,
    this.memberIds = const [],
  });

  final int id;
  final String name;
  final bool isDm;
  final String? createdAt;
  final List<int> memberIds;

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as int,
        name: json['name'] as String,
        isDm: json['is_dm'] == true || json['is_dm'] == 1,
        createdAt: json['created_at'] as String?,
        memberIds: (json['member_ids'] as List<dynamic>? ?? [])
            .map((e) => e as int)
            .toList(),
      );
}
