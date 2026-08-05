class ReplyPreview {
  final int id;
  final String? senderDisplayName;
  final String? content;
  final String? mediaType;
  final bool deleted;

  const ReplyPreview({
    required this.id,
    this.senderDisplayName,
    this.content,
    this.mediaType,
    this.deleted = false,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) => ReplyPreview(
        id: json['id'] as int,
        senderDisplayName: json['sender_display_name'] as String?,
        content: json['content'] as String?,
        mediaType: json['media_type'] as String?,
        deleted: json['deleted'] == true,
      );
}

class MentionRef {
  final String kind; // user | room
  final int id;
  final String? username;
  final String? displayName;
  final String? publicId;
  final String? name;
  final String? roomKind;

  const MentionRef({
    required this.kind,
    required this.id,
    this.username,
    this.displayName,
    this.publicId,
    this.name,
    this.roomKind,
  });

  factory MentionRef.fromJson(Map<String, dynamic> json) => MentionRef(
        kind: json['kind'] as String,
        id: json['id'] as int,
        username: json['username'] as String?,
        displayName: json['display_name'] as String?,
        publicId: json['public_id'] as String?,
        name: json['name'] as String?,
        roomKind: json['room_kind'] as String?,
      );

  String get handle =>
      kind == 'user' ? '@${username ?? id}' : '@${publicId ?? name ?? id}';
}

class Message {
  final int id;
  final int roomId;
  final int senderId;
  final String? content;
  final String? imagePath;
  final String? mediaPath;
  final String? mediaType; // image | video | audio | file
  final String? fileName;
  final int? replyToId;
  final ReplyPreview? replyPreview;
  final int? forwardedFromId;
  final bool isForwarded;
  final bool deleted;
  final String deliveryStatus; // sent | delivered | read
  final List<MentionRef> mentions;
  final String createdAt;
  final String? senderDisplayName;
  final String? senderAvatarPath;
  final bool pending;

  const Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.content,
    this.imagePath,
    this.mediaPath,
    this.mediaType,
    this.fileName,
    this.replyToId,
    this.replyPreview,
    this.forwardedFromId,
    this.isForwarded = false,
    this.deleted = false,
    this.deliveryStatus = 'sent',
    this.mentions = const [],
    required this.createdAt,
    this.senderDisplayName,
    this.senderAvatarPath,
    this.pending = false,
  });

  String? get effectiveMediaPath => mediaPath ?? imagePath;

  factory Message.fromJson(Map<String, dynamic> json) {
    final replyRaw = json['reply_preview'];
    final mentionsRaw = json['mentions'] as List<dynamic>? ?? const [];
    return Message(
      id: json['id'] as int,
      roomId: json['room_id'] as int,
      senderId: json['sender_id'] as int,
      content: json['content'] as String?,
      imagePath: json['image_path'] as String?,
      mediaPath: json['media_path'] as String?,
      mediaType: json['media_type'] as String?,
      fileName: json['file_name'] as String?,
      replyToId: json['reply_to_id'] as int?,
      replyPreview: replyRaw is Map<String, dynamic>
          ? ReplyPreview.fromJson(replyRaw)
          : null,
      forwardedFromId: json['forwarded_from_id'] as int?,
      isForwarded: json['is_forwarded'] == true || json['is_forwarded'] == 1,
      deleted: json['deleted'] == true || json['deleted'] == 1,
      deliveryStatus: (json['delivery_status'] as String?) ?? 'sent',
      mentions: mentionsRaw
          .whereType<Map>()
          .map((e) => MentionRef.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: (json['created_at'] as String?) ?? '',
      senderDisplayName: json['sender_display_name'] as String?,
      senderAvatarPath: json['sender_avatar_path'] as String?,
    );
  }

  Message copyWith({
    int? id,
    bool? pending,
    bool? deleted,
    String? deliveryStatus,
    String? content,
    String? mediaPath,
    String? mediaType,
    String? fileName,
    List<MentionRef>? mentions,
    String? senderAvatarPath,
  }) =>
      Message(
        id: id ?? this.id,
        roomId: roomId,
        senderId: senderId,
        content: content ?? this.content,
        imagePath: imagePath,
        mediaPath: mediaPath ?? this.mediaPath,
        mediaType: mediaType ?? this.mediaType,
        fileName: fileName ?? this.fileName,
        replyToId: replyToId,
        replyPreview: replyPreview,
        forwardedFromId: forwardedFromId,
        isForwarded: isForwarded,
        deleted: deleted ?? this.deleted,
        deliveryStatus: deliveryStatus ?? this.deliveryStatus,
        mentions: mentions ?? this.mentions,
        createdAt: createdAt,
        senderDisplayName: senderDisplayName,
        senderAvatarPath: senderAvatarPath ?? this.senderAvatarPath,
        pending: pending ?? this.pending,
      );

  Map<String, dynamic> toCacheMap() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'content': content,
        'image_path': imagePath,
        'media_path': mediaPath,
        'media_type': mediaType,
        'file_name': fileName,
        'reply_to_id': replyToId,
        'forwarded_from_id': forwardedFromId,
        'is_forwarded': isForwarded ? 1 : 0,
        'deleted': deleted ? 1 : 0,
        'delivery_status': deliveryStatus,
        'created_at': createdAt,
        'sender_display_name': senderDisplayName,
        'sender_avatar_path': senderAvatarPath,
      };
}
