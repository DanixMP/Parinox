import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import 'chat_theme_settings_screen.dart';
import 'hux_components_screen.dart';
import 'ios_settings_chrome.dart';

class CustomizeSettingsScreen extends ConsumerWidget {
  const CustomizeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final n = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return IosSettingsScaffold(
      title: 'Customize',
      children: [
        const IosSettingsSectionLabel('Design system'),
        IosSettingsGroup(
          children: [
            for (final system in DesignSystem.values)
              IosSettingsTile(
                icon: switch (system) {
                  DesignSystem.hux => Icons.auto_awesome,
                  DesignSystem.ios => Icons.phone_iphone,
                  DesignSystem.parinox => Icons.chat_bubble_outline,
                  DesignSystem.shadcn => Icons.auto_awesome_mosaic_outlined,
                  DesignSystem.shadcnFlutter => Icons.widgets_outlined,
                  DesignSystem.nes => Icons.sports_esports_outlined,
                  DesignSystem.moon => Icons.nightlight_round,
                },
                iconBackground: s.designSystem == system
                    ? IosSettingsAccents.blue
                    : IosSettingsAccents.gray,
                title: designSystemLabel(system),
                value: s.designSystem == system ? 'Selected' : null,
                showChevron: false,
                trailing: s.designSystem == system
                    ? Icon(Icons.check_rounded, color: cs.primary)
                    : null,
                onTap: () => n.patch((x) => x.copyWith(designSystem: system)),
              ),
          ],
        ),
        const IosSettingsFooter(
          'Design system changes buttons, chrome, and chat bubble shapes across the app.',
        ),
        const SizedBox(height: 8),
        const IosSettingsSectionLabel('Navigation bar'),
        IosSettingsGroup(
          children: [
            for (final style in NavBarStyle.values)
              IosSettingsTile(
                icon: switch (style) {
                  NavBarStyle.floating => Icons.crop_16_9_outlined,
                  NavBarStyle.docked => Icons.horizontal_rule,
                  NavBarStyle.minimal => Icons.more_horiz,
                  NavBarStyle.curved => Icons.rounded_corner,
                  NavBarStyle.notch => Icons.circle_outlined,
                },
                iconBackground: s.navBarStyle == style
                    ? IosSettingsAccents.indigo
                    : IosSettingsAccents.gray,
                title: navBarStyleLabel(style),
                showChevron: false,
                trailing: s.navBarStyle == style
                    ? Icon(Icons.check_rounded, color: cs.primary)
                    : null,
                onTap: () => n.patch((x) => x.copyWith(navBarStyle: style)),
              ),
          ],
        ),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.auto_awesome,
              iconBackground: IosSettingsAccents.purple,
              title: 'Hux Components',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HuxComponentsScreen()),
              ),
            ),
            IosSettingsTile(
              icon: Icons.wallpaper_rounded,
              iconBackground: IosSettingsAccents.pink,
              title: 'Chat Themes',
              value: s.activeChatTheme.name,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatThemeSettingsScreen()),
              ),
            ),
          ],
        ),
        const IosSettingsSectionLabel('Color mode'),
        IosSettingsGroup(
          children: [
            for (final mode in AppThemePreference.values)
              IosSettingsTile(
                icon: switch (mode) {
                  AppThemePreference.system => Icons.brightness_auto_rounded,
                  AppThemePreference.light => Icons.light_mode_rounded,
                  AppThemePreference.dark => Icons.dark_mode_rounded,
                },
                iconBackground: IosSettingsAccents.orange,
                title: themeLabel(mode),
                showChevron: false,
                trailing: s.theme == mode
                    ? Icon(Icons.check_rounded, color: cs.primary)
                    : null,
                onTap: () => n.patch((x) => x.copyWith(theme: mode)),
              ),
          ],
        ),
      ],
    );
  }
}
