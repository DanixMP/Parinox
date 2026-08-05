import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hux/hux.dart';
import 'package:moon_design/moon_design.dart';
import 'package:nes_ui/nes_ui.dart';

import '../models/app_settings.dart';
import 'app_motion.dart';
import 'app_palette.dart';
import 'app_theme.dart';

/// Builds [ThemeData] for the selected design system + brightness.
abstract final class DesignSystemThemes {
  static ThemeData resolve({
    required DesignSystem system,
    required Brightness brightness,
  }) {
    final base = switch (system) {
      DesignSystem.hux => _hux(brightness),
      DesignSystem.ios => _ios(brightness),
      DesignSystem.parinox =>
        brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      DesignSystem.shadcn => _shadcn(brightness),
      DesignSystem.shadcnFlutter => _shadcnFlutter(brightness),
      DesignSystem.nes => _nes(brightness),
      DesignSystem.moon => _moon(brightness),
    };
    return base.copyWith(pageTransitionsTheme: AppMotion.pageTransitions);
  }

  static ThemeData _hux(Brightness brightness) {
    final branded =
        brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
    final raw =
        brightness == Brightness.dark ? HuxTheme.darkTheme : HuxTheme.lightTheme;
    final text = GoogleFonts.manropeTextTheme(branded.textTheme);
    return raw.copyWith(
      colorScheme: branded.colorScheme,
      scaffoldBackgroundColor: branded.scaffoldBackgroundColor,
      canvasColor: branded.canvasColor,
      cardColor: branded.cardColor,
      textTheme: text,
      primaryTextTheme: GoogleFonts.manropeTextTheme(branded.primaryTextTheme),
      filledButtonTheme: branded.filledButtonTheme,
      outlinedButtonTheme: branded.outlinedButtonTheme,
      textButtonTheme: branded.textButtonTheme,
      inputDecorationTheme: branded.inputDecorationTheme,
      extensions: [
        ...raw.extensions.values.where((e) => e is! AppPalette),
        brightness == Brightness.dark ? AppPalette.dark : AppPalette.light,
      ],
    );
  }

  static ThemeData _shadcnFlutter(Brightness brightness) {
    // Material-compatible zinc theme aligned with shadcn_flutter aesthetics.
    // (shadcn_flutter's own ThemeData is non-Material; we keep MaterialApp.)
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B),
      onPrimary: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
      primaryContainer: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
      onPrimaryContainer: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B),
      secondary: const Color(0xFF71717A),
      onSecondary: Colors.white,
      secondaryContainer: isDark ? const Color(0xFF3F3F46) : const Color(0xFFF4F4F5),
      onSecondaryContainer: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B),
      tertiary: const Color(0xFF2563EB),
      onTertiary: Colors.white,
      tertiaryContainer: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
      onTertiaryContainer: isDark ? Colors.white : const Color(0xFF1E3A8A),
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
      onErrorContainer: isDark ? Colors.white : const Color(0xFF7F1D1D),
      surface: isDark ? const Color(0xFF09090B) : const Color(0xFFFFFFFF),
      onSurface: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B),
      onSurfaceVariant: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
      outline: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
      outlineVariant: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
      surfaceContainerLowest: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
      surfaceContainer: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
      surfaceContainerHigh: isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
      surfaceContainerHighest: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8),
      inverseSurface: isDark ? const Color(0xFFFAFAFA) : const Color(0xFF18181B),
      onInverseSurface: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
      inversePrimary: const Color(0xFF2563EB),
      shadow: Colors.black,
      scrim: Colors.black,
    );
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final text = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      extensions: [palette],
    );
  }

  static ThemeData _ios(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // iOS system-like blues / greys (not purple AI defaults).
    const iosBlue = Color(0xFF007AFF);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: iosBlue,
      onPrimary: Colors.white,
      primaryContainer: isDark ? const Color(0xFF0A84FF) : const Color(0xFFD6E9FF),
      onPrimaryContainer: isDark ? Colors.white : const Color(0xFF003A75),
      secondary: iosBlue,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5F1FF),
      onSecondaryContainer: isDark ? const Color(0xFFE5E5EA) : const Color(0xFF003A75),
      tertiary: const Color(0xFF5856D6),
      onTertiary: Colors.white,
      tertiaryContainer: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8E7FF),
      onTertiaryContainer: isDark ? Colors.white : const Color(0xFF1C1B4D),
      error: const Color(0xFFFF3B30),
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF5C1512) : const Color(0xFFFFE5E3),
      onErrorContainer: isDark ? const Color(0xFFFFDAD6) : const Color(0xFF410002),
      surface: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      onSurface: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF000000),
      onSurfaceVariant: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70),
      surfaceContainerLowest: isDark ? const Color(0xFF000000) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      surfaceContainer: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      surfaceContainerHigh: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
      surfaceContainerHighest: isDark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6),
      outline: isDark ? const Color(0xFF636366) : const Color(0xFFC7C7CC),
      outlineVariant: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E),
      onInverseSurface: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      inversePrimary: const Color(0xFF64B5FF),
    );

    final textTheme = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    final palette = isDark
        ? AppPalette.dark.copyWith(
            chatCanvas: const Color(0xFF000000),
            composerFill: const Color(0xFF1C1C1E),
            navBar: const Color(0xF21C1C1E),
            bubbleMine: const Color(0xFF0A84FF),
            bubbleTheirs: const Color(0xFF2C2C2E),
            bubbleMineFg: Colors.white,
            bubbleTheirsFg: const Color(0xFFF2F2F7),
          )
        : AppPalette.light.copyWith(
            chatCanvas: const Color(0xFFF2F2F7),
            composerFill: Colors.white,
            navBar: const Color(0xF2F9F9F9),
            bubbleMine: const Color(0xFF007AFF),
            bubbleTheirs: Colors.white,
            bubbleMineFg: Colors.white,
            bubbleTheirsFg: const Color(0xFF000000),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: iosBlue,
        scaffoldBackgroundColor: scheme.surface,
        barBackgroundColor: palette.navBar,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: palette.navBar,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 17,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.secondary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? iosBlue : scheme.onSurfaceVariant,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: iosBlue, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: iosBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 0.5),
      extensions: [palette],
    );
  }

  static ThemeData _shadcn(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? AppTheme.dark() : AppTheme.light();
    final scheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFFFAFAFA),
            onPrimary: Color(0xFF09090B),
            secondary: Color(0xFFA1A1AA),
            onSecondary: Color(0xFF09090B),
            surface: Color(0xFF09090B),
            onSurface: Color(0xFFFAFAFA),
            onSurfaceVariant: Color(0xFFA1A1AA),
            surfaceContainer: Color(0xFF18181B),
            surfaceContainerHigh: Color(0xFF27272A),
            outline: Color(0xFF3F3F46),
            outlineVariant: Color(0xFF27272A),
            error: Color(0xFFEF4444),
          )
        : const ColorScheme.light(
            primary: Color(0xFF18181B),
            onPrimary: Color(0xFFFAFAFA),
            secondary: Color(0xFF71717A),
            onSecondary: Color(0xFFFAFAFA),
            surface: Color(0xFFFAFAFA),
            onSurface: Color(0xFF09090B),
            onSurfaceVariant: Color(0xFF71717A),
            surfaceContainer: Color(0xFFF4F4F5),
            surfaceContainerHigh: Color(0xFFE4E4E7),
            outline: Color(0xFFD4D4D8),
            outlineVariant: Color(0xFFE4E4E7),
            error: Color(0xFFDC2626),
          );
    final text = GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      extensions: [
        ...(base.extensions.values),
        isDark ? AppPalette.dark : AppPalette.light,
      ],
    );
  }

  static ThemeData _nes(Brightness brightness) {
    final nes = flutterNesTheme(brightness: brightness);
    final palette = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    return nes.copyWith(
      extensions: [
        ...nes.extensions.values.where((e) => e is! AppPalette),
        palette,
      ],
    );
  }

  static ThemeData _moon(Brightness brightness) {
    final tokens = brightness == Brightness.dark ? MoonTokens.dark : MoonTokens.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4E46B4),
        brightness: brightness,
      ),
    );
    final palette = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        MoonTheme(tokens: tokens),
        palette,
      ],
    );
  }
}
