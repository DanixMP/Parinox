class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.sourceUrl,
    this.fileName,
    this.durationMs,
    this.liked = false,
    this.addedAt,
    this.playlistIds = const [],
  });

  final String id;
  final String title;
  final String artist;
  final String sourceUrl;
  final String? fileName;
  final int? durationMs;
  final bool liked;
  final String? addedAt;
  final List<String> playlistIds;

  MusicTrack copyWith({
    String? title,
    String? artist,
    String? sourceUrl,
    String? fileName,
    int? durationMs,
    bool? liked,
    String? addedAt,
    List<String>? playlistIds,
  }) =>
      MusicTrack(
        id: id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        fileName: fileName ?? this.fileName,
        durationMs: durationMs ?? this.durationMs,
        liked: liked ?? this.liked,
        addedAt: addedAt ?? this.addedAt,
        playlistIds: playlistIds ?? this.playlistIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'sourceUrl': sourceUrl,
        'fileName': fileName,
        'durationMs': durationMs,
        'liked': liked,
        'addedAt': addedAt,
        'playlistIds': playlistIds,
      };

  factory MusicTrack.fromJson(Map<String, dynamic> json) => MusicTrack(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Unknown',
        artist: json['artist'] as String? ?? 'Unknown artist',
        sourceUrl: json['sourceUrl'] as String? ?? '',
        fileName: json['fileName'] as String?,
        durationMs: (json['durationMs'] as num?)?.toInt(),
        liked: json['liked'] == true,
        addedAt: json['addedAt'] as String?,
        playlistIds: (json['playlistIds'] as List?)?.map((e) => '$e').toList() ??
            const [],
      );
}

class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.name,
    this.trackIds = const [],
  });

  final String id;
  final String name;
  final List<String> trackIds;

  MusicPlaylist copyWith({String? name, List<String>? trackIds}) =>
      MusicPlaylist(
        id: id,
        name: name ?? this.name,
        trackIds: trackIds ?? this.trackIds,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trackIds': trackIds,
      };

  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Playlist',
        trackIds:
            (json['trackIds'] as List?)?.map((e) => '$e').toList() ?? const [],
      );
}

class MusicLibraryState {
  const MusicLibraryState({
    this.tracks = const [],
    this.playlists = const [],
  });

  final List<MusicTrack> tracks;
  final List<MusicPlaylist> playlists;

  List<MusicTrack> get liked => tracks.where((t) => t.liked).toList();

  MusicLibraryState copyWith({
    List<MusicTrack>? tracks,
    List<MusicPlaylist>? playlists,
  }) =>
      MusicLibraryState(
        tracks: tracks ?? this.tracks,
        playlists: playlists ?? this.playlists,
      );

  Map<String, dynamic> toJson() => {
        'tracks': tracks.map((e) => e.toJson()).toList(),
        'playlists': playlists.map((e) => e.toJson()).toList(),
      };

  factory MusicLibraryState.fromJson(Map<String, dynamic> json) =>
      MusicLibraryState(
        tracks: (json['tracks'] as List?)
                ?.whereType<Map>()
                .map((e) => MusicTrack.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        playlists: (json['playlists'] as List?)
                ?.whereType<Map>()
                .map((e) => MusicPlaylist.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );
}
