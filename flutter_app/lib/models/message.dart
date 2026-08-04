class Message {
  final int id;
  final int roomId;
  final int senderId;
  final String? content;
  final String? imagePath;
  final String createdAt;
  final String? senderDisplayName;
  final bool pending; // local outbound not yet acked

  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.content,
    this.imagePath,
    required this.createdAt,
    this.senderDisplayName,
    this.pending = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as int,
        roomId: json['room_id'] as int,
        senderId: json['sender_id'] as int,
        content: json['content'] as String?,
        imagePath: json['image_path'] as String?,
        createdAt: json['created_at'] as String,
        senderDisplayName: json['sender_display_name'] as String?,
      );

  Message copyWith({int? id, bool? pending}) => Message(
        id: id ?? this.id,
        roomId: roomId,
        senderId: senderId,
        content: content,
        imagePath: imagePath,
        createdAt: createdAt,
        senderDisplayName: senderDisplayName,
        pending: pending ?? this.pending,
      );

  Map<String, dynamic> toCacheMap() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'content': content,
        'image_path': imagePath,
        'created_at': createdAt,
        'sender_display_name': senderDisplayName,
      };
}
