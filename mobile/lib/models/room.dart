import 'user.dart';

enum RoomKind {
  channel,
  group,
  dm;

  static RoomKind fromJson(dynamic raw, {bool isDm = false}) {
    final value = (raw ?? '').toString().toLowerCase();
    switch (value) {
      case 'channel':
        return RoomKind.channel;
      case 'dm':
        return RoomKind.dm;
      case 'group':
        return RoomKind.group;
      default:
        return isDm ? RoomKind.dm : RoomKind.group;
    }
  }

  String get apiValue => name;

  String get label {
    switch (this) {
      case RoomKind.channel:
        return 'Channels';
      case RoomKind.group:
        return 'Groups';
      case RoomKind.dm:
        return 'Direct messages';
    }
  }
}

class LastMessagePreview {
  final int id;
  final String? content;
  final String? mediaType;
  final int senderId;
  final String? senderDisplayName;
  final String createdAt;
  final bool deleted;

  const LastMessagePreview({
    required this.id,
    this.content,
    this.mediaType,
    required this.senderId,
    this.senderDisplayName,
    required this.createdAt,
    this.deleted = false,
  });

  factory LastMessagePreview.fromJson(Map<String, dynamic> json) => LastMessagePreview(
        id: json['id'] as int,
        content: json['content'] as String?,
        mediaType: json['media_type'] as String?,
        senderId: json['sender_id'] as int,
        senderDisplayName: json['sender_display_name'] as String?,
        createdAt: (json['created_at'] as String?) ?? '',
        deleted: json['deleted'] == true || json['deleted'] == 1,
      );

  String previewText() {
    if (deleted) return 'Message deleted';
    if (content != null && content!.trim().isNotEmpty) return content!.trim();
    return switch (mediaType) {
      'image' => 'Photo',
      'video' => 'Video',
      'audio' => 'Music',
      'file' => 'File',
      _ => '',
    };
  }
}

class Room {
  final int id;
  final String name;
  final RoomKind kind;
  final bool isDm;
  final String description;
  final String? avatarPath;
  final String? publicId;
  final String? inviteToken;
  final int? createdBy;
  final String? createdAt;
  final List<User> members;
  final LastMessagePreview? lastMessage;
  final int unreadCount;
  final String myRole;
  final bool canPost;

  const Room({
    required this.id,
    required this.name,
    required this.kind,
    required this.isDm,
    this.description = '',
    this.avatarPath,
    this.publicId,
    this.inviteToken,
    this.createdBy,
    this.createdAt,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.myRole = 'member',
    this.canPost = true,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final rawDm = json['is_dm'];
    final isDm = rawDm is bool ? rawDm : (rawDm == 1 || rawDm == '1');
    final kind = RoomKind.fromJson(json['kind'], isDm: isDm);
    final lastRaw = json['last_message'];
    final canPostRaw = json['can_post'];
    final canPost = canPostRaw is bool
        ? canPostRaw
        : (kind != RoomKind.channel); // safe default
    return Room(
      id: json['id'] as int,
      name: json['name'] as String,
      kind: kind,
      isDm: kind == RoomKind.dm || isDm,
      description: (json['description'] as String?) ?? '',
      avatarPath: json['avatar_path'] as String?,
      publicId: json['public_id'] as String?,
      inviteToken: json['invite_token'] as String?,
      createdBy: json['created_by'] as int?,
      createdAt: json['created_at'] as String?,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((e) => User.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastMessage: lastRaw is Map<String, dynamic>
          ? LastMessagePreview.fromJson(lastRaw)
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      myRole: (json['my_role'] as String?) ?? 'member',
      canPost: canPost,
    );
  }

  String? get atId => publicId == null || publicId!.isEmpty ? null : '@$publicId';

  String? get inviteShareCode =>
      inviteToken == null || inviteToken!.isEmpty ? null : 'parinox://join/$inviteToken';

  bool get canManageMembers => myRole == 'owner' || myRole == 'admin';

  bool get canEditProfile => myRole == 'owner' || myRole == 'admin';

  /// Display title: for DMs prefer the other person's name.
  String displayTitle(int? myUserId) {
    if (kind == RoomKind.dm && myUserId != null) {
      final others = members.where((m) => m.id != myUserId).toList();
      if (others.isNotEmpty) {
        return others.map((m) => m.displayName).join(', ');
      }
    }
    if (kind == RoomKind.channel && !name.startsWith('#')) {
      return '#$name';
    }
    return name;
  }

  /// Avatar for list / app bar: room avatar, or peer avatar for DMs.
  String? listAvatarPath(int? myUserId) {
    if (avatarPath != null && avatarPath!.isNotEmpty) return avatarPath;
    if (kind == RoomKind.dm && myUserId != null) {
      final peers = members.where((m) => m.id != myUserId).toList();
      if (peers.isNotEmpty) return peers.first.avatarPath;
    }
    return null;
  }
}
