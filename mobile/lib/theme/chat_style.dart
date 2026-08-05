import 'package:flutter/material.dart';
import 'package:nes_ui/nes_ui.dart';

import '../models/app_settings.dart';
import '../models/chat_theme.dart';
import '../models/room.dart';
import '../utils/wallpaper_file.dart';
import 'app_palette.dart';
import 'room_kind_style.dart';

/// Design-system–specific bubble chrome (shape, border, shadow).
abstract final class ChatBubbleStyle {
  static BoxDecoration bubble({
    required DesignSystem system,
    required Color color,
    required bool mine,
    required bool selected,
    required ColorScheme scheme,
    required Color shadow,
  }) {
    final selectedBorder = selected
        ? Border.all(color: scheme.secondary, width: 2)
        : null;

    return switch (system) {
      DesignSystem.nes => BoxDecoration(
          color: color,
          borderRadius: BorderRadius.zero,
          border: selectedBorder ??
              Border.all(color: const Color(0xFF212529), width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF212529),
              offset: Offset(3, 3),
            ),
          ],
        ),
      DesignSystem.hux || DesignSystem.ios => BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: selectedBorder,
          boxShadow: [
            BoxShadow(
              color: shadow.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      DesignSystem.shadcn || DesignSystem.shadcnFlutter => BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: selectedBorder ??
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        ),
      DesignSystem.moon => BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: selectedBorder,
          boxShadow: [
            BoxShadow(
              color: shadow.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      DesignSystem.parinox => BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadii.bubble),
            topRight: const Radius.circular(AppRadii.bubble),
            bottomLeft: Radius.circular(mine ? AppRadii.bubble : 4),
            bottomRight: Radius.circular(mine ? 4 : AppRadii.bubble),
          ),
          border: selectedBorder,
          boxShadow: [
            BoxShadow(
              color: shadow,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
    };
  }

  static EdgeInsets bubblePadding(DesignSystem system) => switch (system) {
        DesignSystem.nes => const EdgeInsets.fromLTRB(10, 8, 10, 8),
        DesignSystem.hux ||
        DesignSystem.ios ||
        DesignSystem.shadcn ||
        DesignSystem.shadcnFlutter =>
          const EdgeInsets.fromLTRB(12, 8, 12, 8),
        DesignSystem.moon => const EdgeInsets.fromLTRB(14, 10, 14, 10),
        DesignSystem.parinox => const EdgeInsets.fromLTRB(10, 6, 10, 5),
      };

  static BoxDecoration dateChip(DesignSystem system, ColorScheme scheme) =>
      switch (system) {
        DesignSystem.nes => BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0xFF212529), width: 2),
          ),
        DesignSystem.hux || DesignSystem.ios || DesignSystem.parinox =>
          BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
          ),
        DesignSystem.shadcn || DesignSystem.shadcnFlutter => BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: scheme.outlineVariant),
          ),
        DesignSystem.moon => BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
          ),
      };

  static BoxDecoration composerField(DesignSystem system, ColorScheme scheme) =>
      switch (system) {
        DesignSystem.nes => BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: const Color(0xFF212529), width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0xFF212529), offset: Offset(3, 3)),
            ],
          ),
        DesignSystem.hux || DesignSystem.ios || DesignSystem.parinox =>
          BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(22),
          ),
        DesignSystem.shadcn || DesignSystem.shadcnFlutter => BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
        DesignSystem.moon => BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
      };
}

/// Wraps bubble content with design-system chrome (NES uses real [NesContainer]).
class ChatBubbleChrome extends StatelessWidget {
  const ChatBubbleChrome({
    super.key,
    required this.system,
    required this.color,
    required this.mine,
    required this.selected,
    required this.child,
    this.roomKind,
  });

  final DesignSystem system;
  final Color color;
  final bool mine;
  final bool selected;
  final Widget child;
  final RoomKind? roomKind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final padding = ChatBubbleStyle.bubblePadding(system);

    if (system == DesignSystem.nes) {
      Widget bubble = NesContainer(
        backgroundColor: color,
        borderColor: selected ? scheme.secondary : const Color(0xFF212529),
        padding: padding,
        child: child,
      );
      if (selected) {
        bubble = DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.secondary, width: 2),
          ),
          child: bubble,
        );
      }
      return bubble;
    }

    var decoration = ChatBubbleStyle.bubble(
      system: system,
      color: color,
      mine: mine,
      selected: selected,
      scheme: scheme,
      shadow: palette.pinShadow,
    );
    if (roomKind != null) {
      decoration = decoration.copyWith(
        borderRadius: RoomKindStyle.bubbleRadius(roomKind!, mine: mine),
      );
    }

    return DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Renders chat wallpaper + optional design-system character overlay.
class ChatWallpaperBackground extends StatelessWidget {
  const ChatWallpaperBackground({
    super.key,
    required this.wallpaperId,
    required this.child,
    this.designSystem = DesignSystem.parinox,
    this.roomKind,
  });

  final String wallpaperId;
  final Widget child;
  final DesignSystem designSystem;
  final RoomKind? roomKind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final solid = ChatWallpapers.solidColor(wallpaperId);
    final filePath = ChatWallpapers.filePath(wallpaperId);

    Widget background;
    if (filePath != null) {
      background = chatWallpaperFileImage(
        filePath,
        fit: BoxFit.cover,
        errorChild: ColoredBox(color: palette.chatBackground(context)),
      );
    } else if (solid != null) {
      background = ColoredBox(color: solid);
    } else {
      background = switch (wallpaperId) {
        ChatWallpapers.dusk => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1B2838),
                  scheme.primary.withValues(alpha: 0.45),
                  const Color(0xFF0E1621),
                ],
              ),
            ),
          ),
        ChatWallpapers.mint => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFD8F3DC),
                  palette.chatBackground(context),
                ],
              ),
            ),
          ),
        ChatWallpapers.graphite => const ColoredBox(color: Color(0xFF1A1D23)),
        ChatWallpapers.peach => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFE5D9),
                  scheme.surface,
                  const Color(0xFFFFCAD4),
                ],
              ),
            ),
          ),
        ChatWallpapers.ocean => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF023E8A),
                  Color(0xFF0077B6),
                  Color(0xFF00B4D8),
                ],
              ),
            ),
          ),
        ChatWallpapers.lattice ||
        ChatWallpapers.pixels ||
        ChatWallpapers.dots =>
          CustomPaint(
            painter: _WallpaperPatternPainter(
              id: wallpaperId,
              base: palette.chatBackground(context),
              accent: scheme.primary.withValues(alpha: 0.18),
            ),
            child: const SizedBox.expand(),
          ),
        _ => ColoredBox(color: palette.chatBackground(context)),
      };
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: background),
        if (roomKind != null)
          Positioned.fill(
            child: ColoredBox(
              color: RoomKindStyle.accent(roomKind!, scheme).withValues(alpha: 0.06),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: _DesignSystemCharacterOverlay(system: designSystem),
          ),
        ),
        child,
      ],
    );
  }
}

/// Soft watermark that gives each design system its “character” in chat.
class _DesignSystemCharacterOverlay extends StatelessWidget {
  const _DesignSystemCharacterOverlay({required this.system});

  final DesignSystem system;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (system) {
      DesignSystem.nes => Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, bottom: 28),
            child: Opacity(
              opacity: 0.18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NesIcon(iconData: NesIcons.gamepad, size: const Size.square(56)),
                  const SizedBox(height: 12),
                  NesIcon(iconData: NesIcons.tv, size: const Size.square(40)),
                ],
              ),
            ),
          ),
        ),
      DesignSystem.hux => Align(
          alignment: Alignment.center,
          child: Icon(
            Icons.auto_awesome_outlined,
            size: 110,
            color: scheme.primary.withValues(alpha: 0.07),
          ),
        ),
      DesignSystem.ios => Align(
          alignment: Alignment.center,
          child: Icon(
            Icons.chat_bubble_outline,
            size: 120,
            color: scheme.primary.withValues(alpha: 0.06),
          ),
        ),
      DesignSystem.shadcn || DesignSystem.shadcnFlutter => CustomPaint(
          painter: _WallpaperPatternPainter(
            id: ChatWallpapers.lattice,
            base: Colors.transparent,
            accent: scheme.onSurface.withValues(alpha: 0.04),
          ),
        ),
      DesignSystem.moon => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Icon(
              Icons.nightlight_round,
              size: 96,
              color: scheme.primary.withValues(alpha: 0.08),
            ),
          ),
        ),
      DesignSystem.parinox => const SizedBox.shrink(),
    };
  }
}

class _WallpaperPatternPainter extends CustomPainter {
  _WallpaperPatternPainter({
    required this.id,
    required this.base,
    required this.accent,
  });

  final String id;
  final Color base;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (base.a > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = base);
    }
    final paint = Paint()..color = accent;

    if (id == ChatWallpapers.dots) {
      const step = 18.0;
      for (var y = 0.0; y < size.height; y += step) {
        for (var x = 0.0; x < size.width; x += step) {
          canvas.drawCircle(Offset(x + 4, y + 4), 1.6, paint);
        }
      }
      return;
    }

    if (id == ChatWallpapers.pixels) {
      const step = 12.0;
      for (var y = 0.0; y < size.height; y += step) {
        for (var x = 0.0; x < size.width; x += step) {
          if (((x ~/ step) + (y ~/ step)).isOdd) {
            canvas.drawRect(Rect.fromLTWH(x, y, step - 1, step - 1), paint);
          }
        }
      }
      return;
    }

    const step = 28.0;
    final stroke = Paint()
      ..color = accent
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), stroke);
    }
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WallpaperPatternPainter oldDelegate) =>
      oldDelegate.id != id ||
      oldDelegate.base != base ||
      oldDelegate.accent != accent;
}

/// Small preview swatch used on the theme page.
class ChatThemePreviewCard extends StatelessWidget {
  const ChatThemePreviewCard({
    super.key,
    required this.theme,
    required this.system,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final ChatThemeConfig theme;
  final DesignSystem system;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: 132,
            child: ChatWallpaperBackground(
              wallpaperId: theme.wallpaperId,
              designSystem: system,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ChatBubbleChrome(
                        system: system,
                        color: theme.theirsColor,
                        mine: false,
                        selected: false,
                        child: Text(
                          'Hey there',
                          style: TextStyle(color: theme.theirsFg, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ChatBubbleChrome(
                        system: system,
                        color: theme.mineColor,
                        mine: true,
                        selected: false,
                        child: Text(
                          'Hello!',
                          style: TextStyle(color: theme.mineFg, fontSize: 11),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      theme.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                            shadows: const [
                              Shadow(blurRadius: 6, color: Colors.black45),
                            ],
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
