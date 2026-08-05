/// Deprecated compatibility shims — use `theme/theme.dart` instead.
library;

export 'app_palette.dart';
export 'app_theme.dart';

import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_theme.dart';

@Deprecated('Use AppTheme.brandPrimary')
abstract final class PxColors {
  static const primary = AppTheme.brandPrimary;
  static const primaryContainer = AppTheme.brandPrimaryBright;
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFFD4E4F2);
  static const primaryFixed = Color(0xFFD4E4F2);
  static const secondary = AppTheme.telegramBlue;
  static const secondaryContainer = Color(0xFF2170E4);
  static const onSecondary = Color(0xFFFFFFFF);
  static const tertiary = Color(0xFF8F1E62);
  static const tertiaryContainer = Color(0xFFAE397B);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF7F7F7);
  static const surfaceContainer = Color(0xFFF0F0F0);
  static const surfaceContainerHigh = Color(0xFFE8E8E8);
  static const surfaceContainerHighest = Color(0xFFE0E0E0);
  static const surfaceVariant = Color(0xFFE0E0E0);
  static const onSurface = Color(0xFF1A1A1A);
  static const onSurfaceVariant = Color(0xFF6D6D6D);
  static const outline = Color(0xFF8E8E8E);
  static const outlineVariant = Color(0xFFE0E0E0);
  static const inverseSurface = Color(0xFF2F2F2F);
  static const inverseOnSurface = Color(0xFFF1F1F1);
  static const inversePrimary = Color(0xFFD2BBFF);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const online = Color(0xFF0ACF83);
  static const darkBackground = Color(0xFF0E1621);
  static const darkSurface = Color(0xFF17212B);
  static const darkSurfaceContainer = Color(0xFF1E2A36);
  static const darkOnSurface = Color(0xFFF1F1F1);
}

@Deprecated('Use AppRadii')
abstract final class PxRadii {
  static const sm = AppRadii.sm;
  static const md = AppRadii.md;
  static const lg = AppRadii.lg;
  static const xl = AppRadii.xl;
  static const xxl = 32.0;
  static const full = AppRadii.full;
}

@Deprecated('Use AppPalette.pinShadow')
abstract final class PxShadows {
  static List<BoxShadow> get z1 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
  static List<BoxShadow> get z2 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
  static List<BoxShadow> get primaryGlow => z2;
}
