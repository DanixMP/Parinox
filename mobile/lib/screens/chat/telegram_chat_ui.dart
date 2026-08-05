import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../models/app_settings.dart';
import '../../models/chat_theme.dart';
import '../../models/message.dart';
import '../../models/music.dart';
import '../../models/room.dart';
import '../../models/user.dart';
import '../../providers/music_provider.dart';
import '../../services/media_url.dart';
import '../../theme/theme.dart';
import '../../widgets/zoomable_avatar.dart';
import '../profile/profile_screen.dart';
import 'room_info_screen.dart';
import 'sticker_gif_sheet.dart';

sealed class ChatListItem {
  const ChatListItem();
}

class ChatDateHeader extends ChatListItem {
  const ChatDateHeader(this.label);
  final String label;
}

class ChatMessageItem extends ChatListItem {
  const ChatMessageItem(this.message);
  final Message message;
}

List<ChatListItem> buildChatListItems(List<Message> messages) {
  final out = <ChatListItem>[];
  DateTime? lastDay;
  for (final m in messages) {
    final day = _messageDay(m.createdAt);
    if (day != null && (lastDay == null || !_sameDay(lastDay, day))) {
      out.add(ChatDateHeader(formatDateSeparator(day)));
      lastDay = day;
    }
    out.add(ChatMessageItem(m));
  }
  return out;
}

DateTime? _messageDay(String createdAt) {
  if (createdAt.isEmpty) return null;
  try {
    return DateTime.parse(createdAt.endsWith('Z') ? createdAt : '${createdAt}Z')
        .toLocal();
  } catch (_) {
    return null;
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatDateSeparator(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  if (d.year == today.year) return DateFormat('EEEE, MMM d').format(d);
  return DateFormat('MMM d, y').format(d);
}

String formatMessageClock(String createdAt) {
  final dt = _messageDay(createdAt);
  if (dt == null) return '';
  return DateFormat('HH:mm').format(dt);
}

String formatChatListTime(String createdAt) {
  final dt = _messageDay(createdAt);
  if (dt == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  if (d == today) return DateFormat('HH:mm').format(dt);
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
  return DateFormat('dd/MM/yy').format(dt);
}

/// Telegram-style message list + bubbles. Uses [ChatThemeConfig] + design system chrome.
class TelegramMessageList extends StatelessWidget {
  const TelegramMessageList({
    super.key,
    required this.messages,
    required this.myId,
    required this.mediaBase,
    required this.scrollController,
    required this.onLongPress,
    this.onTap,
    this.onDismissMenu,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.menuMessageId,
    this.showReadReceipts = true,
    this.autoLoadPhotos = true,
    this.autoLoadVideos = true,
    this.autoLoadFiles = true,
    this.chatTheme = ChatThemePresets.classic,
    this.designSystem = DesignSystem.hux,
    this.roomKind = RoomKind.dm,
    this.onReply,
    this.onCopy,
    this.onForward,
    this.onDelete,
  });

  final List<Message> messages;
  final int? myId;
  final String mediaBase;
  final ScrollController scrollController;
  final void Function(Message) onLongPress;
  final void Function(Message)? onTap;
  final VoidCallback? onDismissMenu;
  final bool selectionMode;
  final Set<int> selectedIds;
  final int? menuMessageId;
  final bool showReadReceipts;
  final bool autoLoadPhotos;
  final bool autoLoadVideos;
  final bool autoLoadFiles;
  final ChatThemeConfig chatTheme;
  final DesignSystem designSystem;
  final RoomKind roomKind;
  final void Function(Message)? onReply;
  final void Function(Message)? onCopy;
  final void Function(Message)? onForward;
  final void Function(Message)? onDelete;

  @override
  Widget build(BuildContext context) {
    final items = buildChatListItems(messages);
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: onDismissMenu,
      child: ChatWallpaperBackground(
        wallpaperId: chatTheme.wallpaperId,
        designSystem: designSystem,
        roomKind: roomKind,
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            if (item is ChatDateHeader) {
              return _DateSeparatorChip(
                label: item.label,
                designSystem: designSystem,
              );
            }
            final m = (item as ChatMessageItem).message;
            final mine = m.senderId == myId;
            final showAvatar = !mine;
            final selected = selectedIds.contains(m.id);
            final menuOpen = menuMessageId == m.id;
            final bubbleColor = mine ? chatTheme.mineColor : chatTheme.theirsColor;
            final stickerOnly = isStickerLikeMessage(m.content) &&
                (m.mediaType == null || m.mediaType!.isEmpty) &&
                !m.deleted;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment:
                        mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      AnimatedSize(
                        duration: AppMotion.fast,
                        curve: AppMotion.curve,
                        child: selectionMode
                            ? Padding(
                                padding: const EdgeInsets.only(right: 6, bottom: 8),
                                child: AnimatedSwitcher(
                                  duration: AppMotion.fast,
                                  child: Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    key: ValueKey(selected),
                                    size: 22,
                                    color: selected
                                        ? Theme.of(context).colorScheme.secondary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (showAvatar) ...[
                        _SenderAvatar(message: m, mediaBase: mediaBase),
                        const SizedBox(width: 6),
                      ] else
                        const SizedBox(width: 34),
                      Flexible(
                        child: Align(
                          alignment:
                              mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: SoftPress(
                            onLongPress: () => onLongPress(m),
                            onTap: onTap == null ? null : () => onTap!(m),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                              ),
                              child: AnimatedSlide(
                                duration: AppMotion.fast,
                                curve: AppMotion.curve,
                                offset: menuOpen ? const Offset(0, -0.02) : Offset.zero,
                                child: stickerOnly
                                    ? DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          border: selected || menuOpen
                                              ? Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary,
                                                  width: 2,
                                                )
                                              : null,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: TelegramBubbleBody(
                                            message: m,
                                            mine: mine,
                                            mediaBase: mediaBase,
                                            showReadReceipts: showReadReceipts,
                                            autoLoadPhotos: autoLoadPhotos,
                                            autoLoadVideos: autoLoadVideos,
                                            autoLoadFiles: autoLoadFiles,
                                            foreground: mine
                                                ? chatTheme.mineFg
                                                : chatTheme.theirsFg,
                                            stickerStyle: true,
                                          ),
                                        ),
                                      )
                                    : ChatBubbleChrome(
                                        system: designSystem,
                                        color: bubbleColor,
                                        mine: mine,
                                        selected: selected || menuOpen,
                                        roomKind: roomKind,
                                        child: TelegramBubbleBody(
                                          message: m,
                                          mine: mine,
                                          mediaBase: mediaBase,
                                          showReadReceipts: showReadReceipts,
                                          autoLoadPhotos: autoLoadPhotos,
                                          autoLoadVideos: autoLoadVideos,
                                          autoLoadFiles: autoLoadFiles,
                                          foreground: mine
                                              ? chatTheme.mineFg
                                              : chatTheme.theirsFg,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (mine) const SizedBox(width: 4),
                    ],
                  ),
                  AnimatedSize(
                    duration: AppMotion.normal,
                    curve: AppMotion.curve,
                    alignment: mine ? Alignment.topRight : Alignment.topLeft,
                    child: menuOpen && !selectionMode
                        ? Padding(
                            padding: EdgeInsets.only(
                              top: 6,
                              left: mine ? 40 : 40,
                              right: mine ? 4 : 40,
                            ),
                            child: _MessageActionDrawer(
                              mine: mine,
                              canCopy: m.content != null &&
                                  m.content!.trim().isNotEmpty,
                              canDelete: mine,
                              onReply: () => onReply?.call(m),
                              onCopy: () => onCopy?.call(m),
                              onForward: () => onForward?.call(m),
                              onDelete: () => onDelete?.call(m),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact action strip anchored under a message bubble.
class _MessageActionDrawer extends StatelessWidget {
  const _MessageActionDrawer({
    required this.mine,
    required this.canCopy,
    required this.canDelete,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    required this.onDelete,
  });

  final bool mine;
  final bool canCopy;
  final bool canDelete;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actions = <({IconData icon, String label, VoidCallback onTap, Color? color})>[
      (icon: Icons.reply_rounded, label: 'Reply', onTap: onReply, color: null),
      if (canCopy)
        (icon: Icons.copy_rounded, label: 'Copy', onTap: onCopy, color: null),
      (
        icon: Icons.forward_rounded,
        label: 'Forward',
        onTap: onForward,
        color: null
      ),
      if (canDelete)
        (
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          onTap: onDelete,
          color: scheme.error
        ),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Material(
          elevation: 6,
          shadowColor: Colors.black26,
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in actions)
                  SoftPress(
                    onTap: a.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(a.icon, size: 18, color: a.color ?? scheme.onSurface),
                          const SizedBox(height: 2),
                          Text(
                            a.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: a.color ?? scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateSeparatorChip extends StatelessWidget {
  const _DateSeparatorChip({
    required this.label,
    required this.designSystem,
  });
  final String label;
  final DesignSystem designSystem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: ChatBubbleStyle.dateChip(designSystem, scheme),
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({required this.message, required this.mediaBase});

  final Message message;
  final String mediaBase;

  @override
  Widget build(BuildContext context) {
    final url = MediaUrl.resolve(mediaBase, message.senderAvatarPath);
    final label = message.senderDisplayName ?? '?';
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: message.senderId)),
        );
      },
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        backgroundImage: url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
        child: url.isEmpty
            ? Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}

class TelegramBubbleBody extends StatelessWidget {
  const TelegramBubbleBody({
    super.key,
    required this.message,
    required this.mine,
    required this.mediaBase,
    this.showReadReceipts = true,
    this.autoLoadPhotos = true,
    this.autoLoadVideos = true,
    this.autoLoadFiles = true,
    this.foreground,
    this.stickerStyle = false,
  });

  final Message message;
  final bool mine;
  final String mediaBase;
  final bool showReadReceipts;
  final bool autoLoadPhotos;
  final bool autoLoadVideos;
  final bool autoLoadFiles;
  final Color? foreground;
  final bool stickerStyle;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final fg = foreground ?? (mine ? palette.bubbleMineFg : palette.bubbleTheirsFg);
    final meta = fg.withValues(alpha: 0.62);

    if (message.deleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Message deleted',
            style: TextStyle(fontStyle: FontStyle.italic, color: meta, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Text(formatMessageClock(message.createdAt), style: TextStyle(fontSize: 11, color: meta)),
        ],
      );
    }

    final mediaUrl = MediaUrl.resolve(mediaBase, message.effectiveMediaPath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!mine && message.senderDisplayName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: message.senderId),
                  ),
                );
              },
              child: Text(
                message.senderDisplayName!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        if (message.isForwarded)
          Text(
            'Forwarded',
            style: TextStyle(fontStyle: FontStyle.italic, color: meta, fontSize: 12),
          ),
        if (message.replyPreview != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.06),
              border: Border(
                left: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.replyPreview!.senderDisplayName ?? 'Message',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  message.replyPreview!.deleted
                      ? 'Deleted message'
                      : (message.replyPreview!.content ??
                          message.replyPreview!.mediaType ??
                          ''),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 13),
                ),
              ],
            ),
          ),
        if (message.mediaType == 'image' && mediaUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _MediaGate(
              autoLoad: autoLoadPhotos,
              label: 'Photo',
              fg: fg,
              meta: meta,
              child: GestureDetector(
                onTap: () => openAvatarViewer(
                  context,
                  heroTag: 'msg-img-${message.id}',
                  imageUrl: mediaUrl,
                  fallbackLabel: 'Image',
                ),
                child: Hero(
                  tag: 'msg-img-${message.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: mediaUrl,
                      width: 220,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => SizedBox(
                        width: 220,
                        height: 140,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Icon(Icons.broken_image_outlined, color: meta),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (message.mediaType == 'video' && mediaUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _MediaGate(
              autoLoad: autoLoadVideos,
              label: 'Video',
              fg: fg,
              meta: meta,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InAppVideoPlayerPage(
                        url: mediaUrl,
                        title: message.fileName ?? 'Video',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 220,
                  height: 120,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill, color: fg, size: 40),
                      Text('Video', style: TextStyle(color: meta)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (message.mediaType == 'audio' && mediaUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _ChatAudioBubble(
              message: message,
              mediaUrl: mediaUrl,
              fg: fg,
              meta: meta,
              autoLoad: autoLoadFiles,
            ),
          ),
        if (message.mediaType == 'file' && mediaUrl.isNotEmpty)
          _MediaGate(
            autoLoad: autoLoadFiles,
            label: message.fileName ?? 'File',
            fg: fg,
            meta: meta,
            child: InkWell(
              onTap: () => launchUrl(Uri.parse(mediaUrl), mode: LaunchMode.externalApplication),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file_outlined, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      message.fileName ?? 'File',
                      style: TextStyle(color: fg, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (message.content != null && message.content!.isNotEmpty)
          stickerStyle || isStickerLikeMessage(message.content)
              ? Text(
                  message.content!.trim(),
                  style: TextStyle(fontSize: stickerStyle ? 56 : 40, height: 1.05),
                )
              : TelegramMentionText(
                  text: message.content!,
                  mentions: message.mentions,
                  color: fg,
                  mentionColor: Theme.of(context).colorScheme.secondary,
                  onMentionTap: (mention) {
                    if (mention.kind == 'user') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ProfileScreen(userId: mention.id)),
                      );
                    } else if (mention.kind == 'room') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => RoomInfoScreen(roomId: mention.id)),
                      );
                    }
                  },
                ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMessageClock(message.createdAt),
              style: TextStyle(fontSize: 11, color: meta),
            ),
            if (message.pending) ...[
              const SizedBox(width: 4),
              Text('Sending…', style: TextStyle(fontSize: 11, color: meta, fontStyle: FontStyle.italic)),
            ] else if (mine && showReadReceipts) ...[
              const SizedBox(width: 3),
              Icon(
                message.deliveryStatus == 'sent' ? Icons.done : Icons.done_all,
                size: 15,
                color: message.deliveryStatus == 'read' ? palette.tickRead : palette.tickSent,
              ),
            ] else if (mine && !showReadReceipts) ...[
              const SizedBox(width: 3),
              Icon(Icons.done, size: 15, color: palette.tickSent),
            ],
          ],
        ),
      ],
    );
  }
}

class _ChatAudioBubble extends ConsumerWidget {
  const _ChatAudioBubble({
    required this.message,
    required this.mediaUrl,
    required this.fg,
    required this.meta,
    required this.autoLoad,
  });

  final Message message;
  final String mediaUrl;
  final Color fg;
  final Color meta;
  final bool autoLoad;

  MusicTrack get _track {
    final name = message.fileName ?? 'Track';
    final title = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    return MusicTrack(
      id: 'chat_${message.id}',
      title: title,
      artist: message.senderDisplayName ?? 'Chat',
      sourceUrl: mediaUrl,
      fileName: message.fileName,
      addedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerProvider);
    final isCurrent = player.current?.id == _track.id;
    final playing = isCurrent && player.playing;
    final lib = ref.watch(musicLibraryProvider).valueOrNull;
    final liked = lib?.tracks.any((t) => t.id == _track.id && t.liked) ?? false;

    return _MediaGate(
      autoLoad: autoLoad,
      label: message.fileName ?? 'Music',
      fg: fg,
      meta: meta,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SoftPress(
              onTap: () async {
                await ref.read(musicLibraryProvider.notifier).addOrUpdateTrack(_track);
                await ref.read(musicPlayerProvider.notifier).playTrack(_track);
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: fg.withValues(alpha: 0.15),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    'Music · tap to play',
                    style: TextStyle(color: meta, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final n = ref.read(musicLibraryProvider.notifier);
                final existing = lib?.tracks.where((x) => x.id == _track.id);
                if (existing == null || existing.isEmpty) {
                  await n.addOrUpdateTrack(_track.copyWith(liked: true));
                } else {
                  await n.toggleLiked(_track.id);
                }
              },
              icon: Icon(
                liked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: liked ? Colors.redAccent : meta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaGate extends StatefulWidget {
  const _MediaGate({
    required this.autoLoad,
    required this.label,
    required this.fg,
    required this.meta,
    required this.child,
  });

  final bool autoLoad;
  final String label;
  final Color fg;
  final Color meta;
  final Widget child;

  @override
  State<_MediaGate> createState() => _MediaGateState();
}

class _MediaGateState extends State<_MediaGate> {
  late bool _load = widget.autoLoad;

  @override
  Widget build(BuildContext context) {
    if (_load) return widget.child;
    return InkWell(
      onTap: () => setState(() => _load = true),
      child: Container(
        width: 220,
        height: 100,
        decoration: BoxDecoration(
          color: widget.fg.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download_outlined, color: widget.fg),
            const SizedBox(height: 4),
            Text('Tap to download ${widget.label}', style: TextStyle(color: widget.meta, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class InAppVideoPlayerPage extends StatefulWidget {
  const InAppVideoPlayerPage({super.key, required this.url, this.title});

  final String url;
  final String? title;

  @override
  State<InAppVideoPlayerPage> createState() => _InAppVideoPlayerPageState();
}

class _InAppVideoPlayerPageState extends State<InAppVideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((e) {
        if (!mounted) return;
        setState(() => _error = e.toString());
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'Video'),
        actions: [
          IconButton(
            tooltip: 'Open externally',
            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white70))
            : !_ready
                ? const CircularProgressIndicator(color: Colors.white54)
                : AspectRatio(
                    aspectRatio: _controller.value.aspectRatio == 0
                        ? 16 / 9
                        : _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller),
                        VideoProgressIndicator(_controller, allowScrubbing: true),
                        Positioned(
                          bottom: 28,
                          child: IconButton(
                            iconSize: 48,
                            color: Colors.white,
                            onPressed: () {
                              setState(() {
                                if (_controller.value.isPlaying) {
                                  _controller.pause();
                                } else {
                                  _controller.play();
                                }
                              });
                            },
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class TelegramMentionText extends StatelessWidget {
  const TelegramMentionText({
    super.key,
    required this.text,
    required this.mentions,
    required this.color,
    required this.mentionColor,
    this.onMentionTap,
  });

  final String text;
  final List<MentionRef> mentions;
  final Color color;
  final Color mentionColor;
  final void Function(MentionRef mention)? onMentionTap;

  @override
  Widget build(BuildContext context) {
    final handles = {for (final m in mentions) m.handle.toLowerCase(): m};
    final spans = <InlineSpan>[];
    final re = RegExp(r'@[A-Za-z][A-Za-z0-9_]{1,31}');
    var start = 0;
    for (final match in re.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final token = match.group(0)!;
      final mention = handles[token.toLowerCase()];
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: mention == null ? null : () => onMentionTap?.call(mention),
            child: Text(
              token,
              style: TextStyle(
                color: mentionColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(color: color, fontSize: 15, height: 1.3),
        children: spans,
      ),
    );
  }
}

class TelegramComposer extends StatelessWidget {
  const TelegramComposer({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
    required this.uploading,
    required this.enterToSend,
    this.onStickers,
    this.designSystem = DesignSystem.hux,
    this.accentColor,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback? onStickers;
  final bool uploading;
  final bool enterToSend;
  final DesignSystem designSystem;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final accent = accentColor ?? scheme.secondary;
    final sendShape = designSystem == DesignSystem.nes
        ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
        : designSystem == DesignSystem.shadcn ||
                designSystem == DesignSystem.shadcnFlutter
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            : designSystem == DesignSystem.hux
                ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                : const CircleBorder();

    return Material(
      color: palette.composerFill,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: uploading ? null : onAttach,
                icon: uploading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.secondary,
                        ),
                      )
                    : Icon(Icons.attach_file, color: scheme.onSurfaceVariant),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: ChatBubbleStyle.composerField(designSystem, scheme),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: TextStyle(color: scheme.onSurface, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    minLines: 1,
                    maxLines: enterToSend ? 1 : 5,
                    textInputAction:
                        enterToSend ? TextInputAction.send : TextInputAction.newline,
                    onSubmitted: (_) {
                      if (enterToSend) onSend();
                    },
                  ),
                ),
              ),
              if (onStickers != null)
                IconButton(
                  tooltip: 'Stickers & GIFs',
                  onPressed: uploading ? null : onStickers,
                  icon: Icon(
                    Icons.emoji_emotions_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: accent,
                  shape: sendShape,
                  child: InkWell(
                    customBorder: sendShape,
                    onTap: onSend,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.send,
                        color: ThemeData.estimateBrightnessForColor(accent) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Caption pop-out before sending image/video (shadcn dialog).
Future<({String caption, bool send})?> showMediaCaptionSheet({
  required BuildContext context,
  required Uint8List bytes,
  required String filename,
  required bool isVideo,
}) {
  final captionCtrl = TextEditingController();
  return showShadDialog<({String caption, bool send})>(
    context: context,
    builder: (ctx) => ShadDialog(
      title: Text(isVideo ? 'Send video' : 'Send photo'),
      description: Text(filename),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(ctx).pop((caption: '', send: false)),
          child: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: () => Navigator.of(ctx).pop(
            (caption: captionCtrl.text.trim(), send: true),
          ),
          child: const Text('Send'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isVideo
                ? Container(
                    height: 180,
                    color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                    child: const Center(
                      child: Icon(Icons.videocam, size: 48),
                    ),
                  )
                : Image.memory(
                    bytes,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(height: 12),
          ShadInput(
            controller: captionCtrl,
            placeholder: const Text('Add a caption…'),
          ),
        ],
      ),
    ),
  ).whenComplete(captionCtrl.dispose);
}

String presenceSubtitle({
  required bool peerOnline,
  String? lastSeenAt,
  required bool wsConnected,
  String? atId,
}) {
  if (!wsConnected) return 'connecting…';
  final parts = <String>[
    if (atId != null) atId,
    formatLastSeen(lastSeenAt, online: peerOnline),
  ];
  return parts.join(' · ');
}
