import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music.dart';

const _libraryKey = 'parinox_music_library_v1';

final musicLibraryProvider =
    AsyncNotifierProvider<MusicLibraryNotifier, MusicLibraryState>(
  MusicLibraryNotifier.new,
);

class MusicLibraryNotifier extends AsyncNotifier<MusicLibraryState> {
  @override
  Future<MusicLibraryState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_libraryKey);
    if (raw == null || raw.isEmpty) {
      return const MusicLibraryState(
        playlists: [
          MusicPlaylist(id: 'favorites', name: 'Favorites'),
          MusicPlaylist(id: 'recent', name: 'Recently added'),
        ],
      );
    }
    try {
      return MusicLibraryState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const MusicLibraryState();
    }
  }

  Future<void> _persist(MusicLibraryState next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_libraryKey, jsonEncode(next.toJson()));
  }

  Future<void> addOrUpdateTrack(MusicTrack track) async {
    final cur = state.valueOrNull ?? const MusicLibraryState();
    final exists = cur.tracks.any((t) => t.id == track.id);
    final tracks = exists
        ? cur.tracks.map((t) => t.id == track.id ? track : t).toList()
        : [track, ...cur.tracks];
    var playlists = cur.playlists;
    if (!exists) {
      playlists = playlists
          .map((p) => p.id == 'recent'
              ? p.copyWith(
                  trackIds: [track.id, ...p.trackIds.where((id) => id != track.id)],
                )
              : p)
          .toList();
    }
    await _persist(cur.copyWith(tracks: tracks, playlists: playlists));
  }

  Future<void> toggleLiked(String trackId) async {
    final cur = state.valueOrNull ?? const MusicLibraryState();
    final tracks = cur.tracks.map((t) {
      if (t.id != trackId) return t;
      return t.copyWith(liked: !t.liked);
    }).toList();
    final likedIds = tracks.where((t) => t.liked).map((t) => t.id).toList();
    final playlists = cur.playlists.map((p) {
      if (p.id != 'favorites') return p;
      return p.copyWith(trackIds: likedIds);
    }).toList();
    await _persist(cur.copyWith(tracks: tracks, playlists: playlists));
  }

  Future<void> createPlaylist(String name) async {
    final cur = state.valueOrNull ?? const MusicLibraryState();
    final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    await _persist(
      cur.copyWith(
        playlists: [...cur.playlists, MusicPlaylist(id: id, name: name)],
      ),
    );
  }

  Future<void> addToPlaylist(String playlistId, String trackId) async {
    final cur = state.valueOrNull ?? const MusicLibraryState();
    final playlists = cur.playlists.map((p) {
      if (p.id != playlistId) return p;
      if (p.trackIds.contains(trackId)) return p;
      return p.copyWith(trackIds: [...p.trackIds, trackId]);
    }).toList();
    await _persist(cur.copyWith(playlists: playlists));
  }

  Future<void> removeTrack(String trackId) async {
    final cur = state.valueOrNull ?? const MusicLibraryState();
    await _persist(
      cur.copyWith(
        tracks: cur.tracks.where((t) => t.id != trackId).toList(),
        playlists: cur.playlists
            .map((p) => p.copyWith(
                  trackIds: p.trackIds.where((id) => id != trackId).toList(),
                ))
            .toList(),
      ),
    );
  }
}

class MusicPlayerState {
  const MusicPlayerState({
    this.queue = const [],
    this.index = 0,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final List<MusicTrack> queue;
  final int index;
  final bool playing;
  final Duration position;
  final Duration duration;

  MusicTrack? get current =>
      queue.isEmpty || index < 0 || index >= queue.length ? null : queue[index];

  MusicPlayerState copyWith({
    List<MusicTrack>? queue,
    int? index,
    bool? playing,
    Duration? position,
    Duration? duration,
  }) =>
      MusicPlayerState(
        queue: queue ?? this.queue,
        index: index ?? this.index,
        playing: playing ?? this.playing,
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );
}

final musicPlayerProvider =
    NotifierProvider<MusicPlayerNotifier, MusicPlayerState>(
  MusicPlayerNotifier.new,
);

class MusicPlayerNotifier extends Notifier<MusicPlayerState> {
  late final AudioPlayer _player;

  @override
  MusicPlayerState build() {
    _player = AudioPlayer();
    ref.onDispose(() => _player.dispose());

    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });
    _player.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });
    _player.playerStateStream.listen((ps) {
      state = state.copyWith(playing: ps.playing);
      if (ps.processingState == ProcessingState.completed) {
        next();
      }
    });

    return const MusicPlayerState();
  }

  Future<void> playTracks(List<MusicTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final i = startIndex.clamp(0, tracks.length - 1);
    state = state.copyWith(queue: tracks, index: i, position: Duration.zero);
    await _loadCurrent();
    await _player.play();
  }

  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? queue}) async {
    final q = queue ?? [track];
    final i = q.indexWhere((t) => t.id == track.id);
    await playTracks(q, startIndex: i < 0 ? 0 : i);
  }

  Future<void> _loadCurrent() async {
    final track = state.current;
    if (track == null || track.sourceUrl.isEmpty) return;
    try {
      await _player.setUrl(track.sourceUrl);
    } catch (_) {
      // Keep UI state even if load fails (offline / bad url).
    }
  }

  Future<void> toggle() async {
    if (state.current == null) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;
    final next = (state.index + 1) % state.queue.length;
    state = state.copyWith(index: next, position: Duration.zero);
    await _loadCurrent();
    await _player.play();
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;
    if (state.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    final prev = (state.index - 1 + state.queue.length) % state.queue.length;
    state = state.copyWith(index: prev, position: Duration.zero);
    await _loadCurrent();
    await _player.play();
  }

  Future<void> seek(Duration pos) => _player.seek(pos);

  Future<void> stop() async {
    await _player.stop();
    state = const MusicPlayerState();
  }
}
