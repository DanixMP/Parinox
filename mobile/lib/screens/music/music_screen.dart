import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/music.dart';
import '../../providers/music_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/ds/ds_button.dart';
import '../../widgets/ds/ds_chrome.dart';

/// Swipeable music hub: Library · Liked · Playlists · Now playing.
class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _page = PageController();
  int _tab = 0;

  static const _titles = ['Library', 'Liked', 'Playlists', 'Now playing'];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _tab = i);
    _page.animateToPage(
      i,
      duration: AppMotion.normal,
      curve: AppMotion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lib = ref.watch(musicLibraryProvider).valueOrNull ??
        const MusicLibraryState();
    final player = ref.watch(musicPlayerProvider);

    return DsScaffold(
      appBar: DsAppBar(
        title: AnimatedSwitcher(
          duration: AppMotion.fast,
          child: Text(_titles[_tab], key: ValueKey(_tab)),
        ),
        actions: [
          IconButton(
            tooltip: 'New playlist',
            onPressed: () => _createPlaylist(context),
            icon: const Icon(Icons.playlist_add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                for (var i = 0; i < _titles.length; i++)
                  Expanded(
                    child: SoftPress(
                      onTap: () => _go(i),
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        curve: AppMotion.curve,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tab == i
                              ? scheme.primary.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _tab == i
                                ? scheme.primary.withValues(alpha: 0.4)
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          _titles[i],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                _tab == i ? FontWeight.w700 : FontWeight.w500,
                            color: _tab == i
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              onPageChanged: (i) => setState(() => _tab = i),
              children: [
                _TrackListPage(
                  empty: 'No tracks yet — send music in chat or add from a message.',
                  tracks: lib.tracks,
                  onPlay: (t) => ref
                      .read(musicPlayerProvider.notifier)
                      .playTrack(t, queue: lib.tracks),
                ),
                _TrackListPage(
                  empty: 'Heart tracks to build your liked list.',
                  tracks: lib.liked,
                  onPlay: (t) => ref
                      .read(musicPlayerProvider.notifier)
                      .playTrack(t, queue: lib.liked),
                ),
                _PlaylistsPage(library: lib),
                _NowPlayingPage(player: player),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    await ref.read(musicLibraryProvider.notifier).createPlaylist(name);
  }
}

class _TrackListPage extends ConsumerWidget {
  const _TrackListPage({
    required this.tracks,
    required this.onPlay,
    required this.empty,
  });

  final List<MusicTrack> tracks;
  final void Function(MusicTrack) onPlay;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            empty,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      itemCount: tracks.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
      itemBuilder: (context, i) {
        final t = tracks[i];
        return SoftPress(
          onTap: () => onPlay(t),
          onLongPress: () => _trackMenu(context, ref, t),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primary.withValues(alpha: 0.15),
              child: Icon(Icons.music_note, color: scheme.primary),
            ),
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: Icon(
                t.liked ? Icons.favorite : Icons.favorite_border,
                color: t.liked ? scheme.error : scheme.onSurfaceVariant,
              ),
              onPressed: () =>
                  ref.read(musicLibraryProvider.notifier).toggleLiked(t.id),
            ),
          ),
        );
      },
    );
  }

  Future<void> _trackMenu(
    BuildContext context,
    WidgetRef ref,
    MusicTrack track,
  ) async {
    final action = await showDsBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Play'),
              onTap: () => Navigator.pop(ctx, 'play'),
            ),
            ListTile(
              leading: Icon(track.liked ? Icons.favorite : Icons.favorite_border),
              title: Text(track.liked ? 'Unlike' : 'Like'),
              onTap: () => Navigator.pop(ctx, 'like'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () => Navigator.pop(ctx, 'playlist'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              title: Text('Remove', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    final lib = ref.read(musicLibraryProvider).valueOrNull;
    switch (action) {
      case 'play':
        onPlay(track);
      case 'like':
        await ref.read(musicLibraryProvider.notifier).toggleLiked(track.id);
      case 'remove':
        await ref.read(musicLibraryProvider.notifier).removeTrack(track.id);
      case 'playlist':
        if (lib == null) return;
        final pl = await showDsBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final p in lib.playlists)
                  ListTile(
                    title: Text(p.name),
                    onTap: () => Navigator.pop(ctx, p.id),
                  ),
              ],
            ),
          ),
        );
        if (pl != null) {
          await ref.read(musicLibraryProvider.notifier).addToPlaylist(pl, track.id);
        }
    }
  }
}

class _PlaylistsPage extends ConsumerWidget {
  const _PlaylistsPage({required this.library});

  final MusicLibraryState library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      itemCount: library.playlists.length,
      itemBuilder: (context, i) {
        final p = library.playlists[i];
        final byId = {for (final t in library.tracks) t.id: t};
        final tracks =
            p.trackIds.map((id) => byId[id]).whereType<MusicTrack>().toList();
        return SoftPress(
          onTap: () {
            if (tracks.isEmpty) return;
            ref.read(musicPlayerProvider.notifier).playTracks(tracks);
          },
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.secondary.withValues(alpha: 0.15),
              child: Icon(Icons.queue_music, color: scheme.secondary),
            ),
            title: Text(p.name),
            subtitle: Text('${tracks.length} tracks'),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}

class _NowPlayingPage extends ConsumerWidget {
  const _NowPlayingPage({required this.player});

  final MusicPlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final track = player.current;
    if (track == null) {
      return Center(
        child: Text(
          'Nothing playing',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final progress = player.duration.inMilliseconds == 0
        ? 0.0
        : (player.position.inMilliseconds / player.duration.inMilliseconds)
            .clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve ~260px for title, slider, and transport; shrink artwork to fit.
        final artSize = (constraints.maxHeight - 260).clamp(112.0, 220.0);
        final gap = constraints.maxHeight < 520 ? 12.0 : 22.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AnimatedScale(
                    scale: player.playing ? 1.0 : 0.96,
                    duration: AppMotion.normal,
                    curve: AppMotion.curve,
                    child: Container(
                      width: artSize,
                      height: artSize,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Icon(
                        Icons.album,
                        size: artSize * 0.44,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: gap),
              Text(
                track.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
              ),
              SizedBox(height: gap),
              Slider(
                value: progress,
                onChanged: (v) {
                  final d = player.duration;
                  ref.read(musicPlayerProvider.notifier).seek(
                        Duration(milliseconds: (d.inMilliseconds * v).round()),
                      );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(player.position),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    _fmt(player.duration),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 36,
                    onPressed: () =>
                        ref.read(musicPlayerProvider.notifier).previous(),
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 12),
                  DsButton(
                    onPressed: () =>
                        ref.read(musicPlayerProvider.notifier).toggle(),
                    child: Icon(
                      player.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    iconSize: 36,
                    onPressed: () =>
                        ref.read(musicPlayerProvider.notifier).next(),
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Compact now-playing bar for home shell.
class MusicMiniPlayer extends ConsumerWidget {
  const MusicMiniPlayer({super.key, this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(musicPlayerProvider);
    final track = player.current;
    if (track == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return SoftPress(
      onTap: onOpen,
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 4,
        child: SafeArea(
          top: false,
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.music_note, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(musicPlayerProvider.notifier).toggle(),
                  icon: Icon(
                    player.playing ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(musicPlayerProvider.notifier).next(),
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
