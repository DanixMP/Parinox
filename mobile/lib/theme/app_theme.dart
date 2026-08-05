import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// Single theming entry point for the whole app.
///
/// Always consume colors via `Theme.of(context).colorScheme` or
/// `AppPalette.of(context)` — never hardcode black/white text for UI chrome.
abstract final class AppTheme {
  // —— Brand tokens (light: jet + white smoke · dark: black + white) ——
  static const jetBlack = Color(0xFF2A3439);
  static const whiteSmoke = Color(0xFFF5F5F5);
  static const softWhite = Color(0xFFFAFAFA);
  static const pureBlack = Color(0xFF000000);
  static const nearBlack = Color(0xFF0A0A0A);
  static const charcoal = Color(0xFF141414);
  static const ash = Color(0xFF1C1C1C);
  static const midGray = Color(0xFF2A2A2A);

  /// App brand primary — jet (light) / white (dark via scheme).
  static const brandPrimary = jetBlack;
  static const brandPrimaryBright = charcoal;
  static const telegramBlue = Color(0xFF8A9296);

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: jetBlack,
          onPrimary: whiteSmoke,
          primaryContainer: Color(0xFFDCE0E2),
          onPrimaryContainer: jetBlack,
          secondary: Color(0xFF4A555A),
          onSecondary: whiteSmoke,
          secondaryContainer: Color(0xFFE8EAEA),
          onSecondaryContainer: jetBlack,
          tertiary: Color(0xFF5C6B73),
          onTertiary: whiteSmoke,
          tertiaryContainer: Color(0xFFE2E6E8),
          onTertiaryContainer: jetBlack,
          error: Color(0xFFBA1A1A),
          onError: whiteSmoke,
          errorContainer: Color(0xFFFFDAD6),
          onErrorContainer: Color(0xFF410002),
          surface: softWhite,
          onSurface: jetBlack,
          onSurfaceVariant: Color(0xFF5C666B),
          surfaceContainerLowest: softWhite,
          surfaceContainerLow: whiteSmoke,
          surfaceContainer: Color(0xFFEEEEEE),
          surfaceContainerHigh: Color(0xFFE6E6E6),
          surfaceContainerHighest: Color(0xFFDEDEDE),
          outline: Color(0xFF8A9296),
          outlineVariant: Color(0xFFD4D6D7),
          shadow: jetBlack,
          scrim: jetBlack,
          inverseSurface: jetBlack,
          onInverseSurface: whiteSmoke,
          inversePrimary: whiteSmoke,
        ),
        scaffold: whiteSmoke,
        palette: AppPalette.light,
        overlay: SystemUiOverlayStyle.dark,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: whiteSmoke,
          onPrimary: pureBlack,
          primaryContainer: midGray,
          onPrimaryContainer: whiteSmoke,
          secondary: Color(0xFFB0B0B0),
          onSecondary: pureBlack,
          secondaryContainer: ash,
          onSecondaryContainer: whiteSmoke,
          tertiary: Color(0xFF9A9A9A),
          onTertiary: pureBlack,
          tertiaryContainer: charcoal,
          onTertiaryContainer: whiteSmoke,
          error: Color(0xFFFFB4AB),
          onError: Color(0xFF690005),
          errorContainer: Color(0xFF93000A),
          onErrorContainer: Color(0xFFFFDAD6),
          surface: nearBlack,
          onSurface: whiteSmoke,
          onSurfaceVariant: Color(0xFFA8A8A8),
          surfaceContainerLowest: pureBlack,
          surfaceContainerLow: nearBlack,
          surfaceContainer: charcoal,
          surfaceContainerHigh: ash,
          surfaceContainerHighest: midGray,
          outline: Color(0xFF6E6E6E),
          outlineVariant: Color(0xFF2E2E2E),
          shadow: pureBlack,
          scrim: pureBlack,
          inverseSurface: whiteSmoke,
          onInverseSurface: pureBlack,
          inversePrimary: jetBlack,
        ),
        scaffold: pureBlack,
        palette: AppPalette.dark,
        overlay: SystemUiOverlayStyle.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
    required AppPalette palette,
    required SystemUiOverlayStyle overlay,
  }) {
    final text = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scheme.surface,
      cardColor: scheme.surfaceContainerLowest,
      dividerColor: palette.divider,
      textTheme: text,
      primaryTextTheme: text,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: overlay,
        titleTextStyle: text.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: palette.navBar,
        indicatorColor: scheme.secondary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.secondary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.secondary : scheme.onSurfaceVariant,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pin),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.secondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        elevation: 3,
        shape: const CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.secondary,
        labelStyle: text.labelMedium!.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelMedium!.copyWith(color: scheme.onSecondary),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.secondary),
      iconTheme: IconThemeData(color: scheme.onSurface),
      primaryIconTheme: IconThemeData(color: scheme.onPrimary),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 0.5,
        space: 0.5,
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ).copyWith(
      bodySmall: base.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      labelMedium: base.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      labelSmall: base.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      titleLarge: base.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Back-compat aliases used by older imports.
ThemeData buildParinoxLightTheme() => AppTheme.light();
ThemeData buildParinoxDarkTheme() => AppTheme.dark();
