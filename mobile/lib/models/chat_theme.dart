import 'package:flutter/material.dart';

/// Built-in wallpaper keys (plus `solid:#AARRGGBB` / `custom` solids).
abstract final class ChatWallpapers {
  static const defaultId = 'default';
  static const dusk = 'dusk';
  static const mint = 'mint';
  static const graphite = 'graphite';
  static const peach = 'peach';
  static const ocean = 'ocean';
  static const lattice = 'lattice';
  static const pixels = 'pixels';
  static const dots = 'dots';

  static const presets = <String>[
    defaultId,
    dusk,
    mint,
    graphite,
    peach,
    ocean,
    lattice,
    pixels,
    dots,
  ];

  static String label(String id) {
    if (id.startsWith('solid:')) return 'Custom color';
    if (id.startsWith('file:')) return 'Uploaded image';
    return switch (id) {
      defaultId => 'Default',
      dusk => 'Dusk gradient',
      mint => 'Mint wash',
      graphite => 'Graphite',
      peach => 'Peach glow',
      ocean => 'Ocean',
      lattice => 'Lattice',
      pixels => 'Pixel grid',
      dots => 'Soft dots',
      _ => id,
    };
  }

  static String solidId(Color color) =>
      'solid:#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

  static String fileId(String absolutePath) => 'file:$absolutePath';

  static String? filePath(String id) {
    if (!id.startsWith('file:')) return null;
    return id.substring(5);
  }

  static Color? solidColor(String id) {
    if (!id.startsWith('solid:#')) return null;
    final hex = id.substring(7);
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return null;
    return Color(value);
  }
}

/// Saved / premade chat color + wallpaper pack.
class ChatThemeConfig {
  const ChatThemeConfig({
    required this.id,
    required this.name,
    required this.bubbleMine,
    required this.bubbleMineFg,
    required this.bubbleTheirs,
    required this.bubbleTheirsFg,
    this.wallpaperId = ChatWallpapers.defaultId,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final int bubbleMine;
  final int bubbleMineFg;
  final int bubbleTheirs;
  final int bubbleTheirsFg;
  final String wallpaperId;
  final bool isCustom;

  Color get mineColor => Color(bubbleMine);
  Color get mineFg => Color(bubbleMineFg);
  Color get theirsColor => Color(bubbleTheirs);
  Color get theirsFg => Color(bubbleTheirsFg);

  ChatThemeConfig copyWith({
    String? id,
    String? name,
    int? bubbleMine,
    int? bubbleMineFg,
    int? bubbleTheirs,
    int? bubbleTheirsFg,
    String? wallpaperId,
    bool? isCustom,
  }) =>
      ChatThemeConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        bubbleMine: bubbleMine ?? this.bubbleMine,
        bubbleMineFg: bubbleMineFg ?? this.bubbleMineFg,
        bubbleTheirs: bubbleTheirs ?? this.bubbleTheirs,
        bubbleTheirsFg: bubbleTheirsFg ?? this.bubbleTheirsFg,
        wallpaperId: wallpaperId ?? this.wallpaperId,
        isCustom: isCustom ?? this.isCustom,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bubbleMine': bubbleMine,
        'bubbleMineFg': bubbleMineFg,
        'bubbleTheirs': bubbleTheirs,
        'bubbleTheirsFg': bubbleTheirsFg,
        'wallpaperId': wallpaperId,
        'isCustom': isCustom,
      };

  factory ChatThemeConfig.fromJson(Map<String, dynamic> json) => ChatThemeConfig(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Theme',
        bubbleMine: (json['bubbleMine'] as num?)?.toInt() ?? 0xFFEFFDDE,
        bubbleMineFg: (json['bubbleMineFg'] as num?)?.toInt() ?? 0xFF000000,
        bubbleTheirs: (json['bubbleTheirs'] as num?)?.toInt() ?? 0xFFFFFFFF,
        bubbleTheirsFg: (json['bubbleTheirsFg'] as num?)?.toInt() ?? 0xFF000000,
        wallpaperId: json['wallpaperId'] as String? ?? ChatWallpapers.defaultId,
        isCustom: json['isCustom'] == true,
      );
}

/// Premade chat themes (independent of app design system).
abstract final class ChatThemePresets {
  static const classic = ChatThemeConfig(
    id: 'classic',
    name: 'Classic Mint',
    bubbleMine: 0xFFEFFDDE,
    bubbleMineFg: 0xFF000000,
    bubbleTheirs: 0xFFFFFFFF,
    bubbleTheirsFg: 0xFF000000,
    wallpaperId: ChatWallpapers.defaultId,
  );

  static const midnight = ChatThemeConfig(
    id: 'midnight',
    name: 'Midnight Blue',
    bubbleMine: 0xFF2B5278,
    bubbleMineFg: 0xFFFFFFFF,
    bubbleTheirs: 0xFF182533,
    bubbleTheirsFg: 0xFFFFFFFF,
    wallpaperId: ChatWallpapers.graphite,
  );

  static const iosBlue = ChatThemeConfig(
    id: 'ios_blue',
    name: 'iOS Blue',
    bubbleMine: 0xFF007AFF,
    bubbleMineFg: 0xFFFFFFFF,
    bubbleTheirs: 0xFFE9E9EB,
    bubbleTheirsFg: 0xFF000000,
    wallpaperId: ChatWallpapers.dusk,
  );

  static const neon = ChatThemeConfig(
    id: 'neon',
    name: 'Neon Arcade',
    bubbleMine: 0xFF92CC41,
    bubbleMineFg: 0xFF000000,
    bubbleTheirs: 0xFF209CEE,
    bubbleTheirsFg: 0xFF000000,
    wallpaperId: ChatWallpapers.pixels,
  );

  static const rose = ChatThemeConfig(
    id: 'rose',
    name: 'Rose Quartz',
    bubbleMine: 0xFFFFB4C8,
    bubbleMineFg: 0xFF3D0026,
    bubbleTheirs: 0xFFFFF0F4,
    bubbleTheirsFg: 0xFF3D0026,
    wallpaperId: ChatWallpapers.peach,
  );

  static const ink = ChatThemeConfig(
    id: 'ink',
    name: 'Shadcn Ink',
    bubbleMine: 0xFF18181B,
    bubbleMineFg: 0xFFFAFAFA,
    bubbleTheirs: 0xFFF4F4F5,
    bubbleTheirsFg: 0xFF09090B,
    wallpaperId: ChatWallpapers.lattice,
  );

  static const moonlit = ChatThemeConfig(
    id: 'moonlit',
    name: 'Moonlit',
    bubbleMine: 0xFF4E46B4,
    bubbleMineFg: 0xFFFFFFFF,
    bubbleTheirs: 0xFFE8E6F8,
    bubbleTheirsFg: 0xFF1A1640,
    wallpaperId: ChatWallpapers.ocean,
  );

  static const all = <ChatThemeConfig>[
    classic,
    midnight,
    iosBlue,
    neon,
    rose,
    ink,
    moonlit,
  ];

  static ChatThemeConfig byId(String id, {List<ChatThemeConfig> custom = const []}) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    for (final t in custom) {
      if (t.id == id) return t;
    }
    return classic;
  }
}
