import 'package:flutter/material.dart';

/// Semantic colors that adapt to light/dark. Prefer these over hardcoded colors.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bubbleMine,
    required this.bubbleMineFg,
    required this.bubbleTheirs,
    required this.bubbleTheirsFg,
    required this.bubbleMetaMine,
    required this.bubbleMetaTheirs,
    required this.tickSent,
    required this.tickRead,
    required this.chatCanvas,
    required this.composerFill,
    required this.unreadBadge,
    required this.online,
    required this.divider,
    required this.pinShadow,
    required this.navBar,
    required this.ambientPrimary,
    required this.ambientSecondary,
  });

  final Color bubbleMine;
  final Color bubbleMineFg;
  final Color bubbleTheirs;
  final Color bubbleTheirsFg;
  final Color bubbleMetaMine;
  final Color bubbleMetaTheirs;
  final Color tickSent;
  final Color tickRead;
  final Color chatCanvas;
  final Color composerFill;
  final Color unreadBadge;
  final Color online;
  final Color divider;
  final Color pinShadow;
  final Color navBar;
  final Color ambientPrimary;
  final Color ambientSecondary;

  /// Telegram-like light messaging palette.
  static const light = AppPalette(
    bubbleMine: Color(0xFFE8EEF0),
    bubbleMineFg: Color(0xFF2A3439),
    bubbleTheirs: Color(0xFFFAFAFA),
    bubbleTheirsFg: Color(0xFF2A3439),
    bubbleMetaMine: Color(0xFF5C666B),
    bubbleMetaTheirs: Color(0xFF8A9296),
    tickSent: Color(0xFF8A9296),
    tickRead: Color(0xFF5C666B),
    chatCanvas: Color(0xFFE8ECED),
    composerFill: Color(0xFFFAFAFA),
    unreadBadge: Color(0xFF2A3439),
    online: Color(0xFF0ACF83),
    divider: Color(0xFFD4D6D7),
    pinShadow: Color(0x142A3439),
    navBar: Color(0xFFF5F5F5),
    ambientPrimary: Color(0x332A3439),
    ambientSecondary: Color(0x265C666B),
  );

  /// Override chat canvas for light (soft smoke).
  static const lightChatCanvas = Color(0xFFE8ECED);

  static const dark = AppPalette(
    bubbleMine: Color(0xFF2A2A2A),
    bubbleMineFg: Color(0xFFF5F5F5),
    bubbleTheirs: Color(0xFF141414),
    bubbleTheirsFg: Color(0xFFF5F5F5),
    bubbleMetaMine: Color(0xFFA8A8A8),
    bubbleMetaTheirs: Color(0xFF6E6E6E),
    tickSent: Color(0xFF6E6E6E),
    tickRead: Color(0xFFF5F5F5),
    chatCanvas: Color(0xFF000000),
    composerFill: Color(0xFF141414),
    unreadBadge: Color(0xFFF5F5F5),
    online: Color(0xFF0ACF83),
    divider: Color(0xFF2E2E2E),
    pinShadow: Color(0x66000000),
    navBar: Color(0xFF0A0A0A),
    ambientPrimary: Color(0x33F5F5F5),
    ambientSecondary: Color(0x33000000),
  );

  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  Color chatBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? chatCanvas : lightChatCanvas;
  }

  @override
  AppPalette copyWith({
    Color? bubbleMine,
    Color? bubbleMineFg,
    Color? bubbleTheirs,
    Color? bubbleTheirsFg,
    Color? bubbleMetaMine,
    Color? bubbleMetaTheirs,
    Color? tickSent,
    Color? tickRead,
    Color? chatCanvas,
    Color? composerFill,
    Color? unreadBadge,
    Color? online,
    Color? divider,
    Color? pinShadow,
    Color? navBar,
    Color? ambientPrimary,
    Color? ambientSecondary,
  }) {
    return AppPalette(
      bubbleMine: bubbleMine ?? this.bubbleMine,
      bubbleMineFg: bubbleMineFg ?? this.bubbleMineFg,
      bubbleTheirs: bubbleTheirs ?? this.bubbleTheirs,
      bubbleTheirsFg: bubbleTheirsFg ?? this.bubbleTheirsFg,
      bubbleMetaMine: bubbleMetaMine ?? this.bubbleMetaMine,
      bubbleMetaTheirs: bubbleMetaTheirs ?? this.bubbleMetaTheirs,
      tickSent: tickSent ?? this.tickSent,
      tickRead: tickRead ?? this.tickRead,
      chatCanvas: chatCanvas ?? this.chatCanvas,
      composerFill: composerFill ?? this.composerFill,
      unreadBadge: unreadBadge ?? this.unreadBadge,
      online: online ?? this.online,
      divider: divider ?? this.divider,
      pinShadow: pinShadow ?? this.pinShadow,
      navBar: navBar ?? this.navBar,
      ambientPrimary: ambientPrimary ?? this.ambientPrimary,
      ambientSecondary: ambientSecondary ?? this.ambientSecondary,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bubbleMine: Color.lerp(bubbleMine, other.bubbleMine, t)!,
      bubbleMineFg: Color.lerp(bubbleMineFg, other.bubbleMineFg, t)!,
      bubbleTheirs: Color.lerp(bubbleTheirs, other.bubbleTheirs, t)!,
      bubbleTheirsFg: Color.lerp(bubbleTheirsFg, other.bubbleTheirsFg, t)!,
      bubbleMetaMine: Color.lerp(bubbleMetaMine, other.bubbleMetaMine, t)!,
      bubbleMetaTheirs: Color.lerp(bubbleMetaTheirs, other.bubbleMetaTheirs, t)!,
      tickSent: Color.lerp(tickSent, other.tickSent, t)!,
      tickRead: Color.lerp(tickRead, other.tickRead, t)!,
      chatCanvas: Color.lerp(chatCanvas, other.chatCanvas, t)!,
      composerFill: Color.lerp(composerFill, other.composerFill, t)!,
      unreadBadge: Color.lerp(unreadBadge, other.unreadBadge, t)!,
      online: Color.lerp(online, other.online, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      pinShadow: Color.lerp(pinShadow, other.pinShadow, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      ambientPrimary: Color.lerp(ambientPrimary, other.ambientPrimary, t)!,
      ambientSecondary: Color.lerp(ambientSecondary, other.ambientSecondary, t)!,
    );
  }
}

/// Brand radii — single place for shape language.
abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const pin = 16.0;
  static const bubble = 14.0;
  static const full = 999.0;
}
