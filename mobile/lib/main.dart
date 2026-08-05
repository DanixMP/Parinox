import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'models/app_settings.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/home_shell.dart';
import 'theme/design_system_themes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TeamApp()));
}

class TeamApp extends ConsumerWidget {
  const TeamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final themeMode = themeModeFromSettings(settings);
    final textScale = settings.fontScale;
    final system = settings.designSystem;

    final home = auth.when(
      data: (state) =>
          state.isAuthenticated ? const HomeShell() : const AuthGate(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const AuthGate(),
    );

    final light = DesignSystemThemes.resolve(
      system: system,
      brightness: Brightness.light,
    );
    final dark = DesignSystemThemes.resolve(
      system: system,
      brightness: Brightness.dark,
    );

    final shadLightScheme = system == DesignSystem.shadcn
        ? const ShadZincColorScheme.light()
        : const ShadVioletColorScheme.light();
    final shadDarkScheme = system == DesignSystem.shadcn
        ? const ShadZincColorScheme.dark()
        : const ShadVioletColorScheme.dark();

    return ShadApp.custom(
      themeMode: themeMode,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: shadLightScheme,
        textTheme: ShadTextTheme(
          family: GoogleFonts.inter().fontFamily,
        ),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: shadDarkScheme,
        textTheme: ShadTextTheme(
          family: GoogleFonts.inter().fontFamily,
        ),
      ),
      appBuilder: (context) {
        return MaterialApp(
          title: 'Parinox',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: light,
          darkTheme: dark,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(textScale)),
              child: ShadAppBuilder(child: child ?? const SizedBox.shrink()),
            );
          },
          home: home,
        );
      },
    );
  }
}
