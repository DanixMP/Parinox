import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import 'ios_settings_chrome.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final n = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return IosSettingsScaffold(
      title: 'Appearance',
      children: [
        const IosSettingsSectionLabel('Color theme'),
        IosSettingsGroup(
          children: [
            for (final mode in AppThemePreference.values)
              IosSettingsTile(
                icon: switch (mode) {
                  AppThemePreference.system => Icons.brightness_auto_rounded,
                  AppThemePreference.light => Icons.light_mode_rounded,
                  AppThemePreference.dark => Icons.dark_mode_rounded,
                },
                iconBackground: switch (mode) {
                  AppThemePreference.system => IosSettingsAccents.gray,
                  AppThemePreference.light => IosSettingsAccents.orange,
                  AppThemePreference.dark => IosSettingsAccents.indigo,
                },
                title: themeLabel(mode),
                showChevron: false,
                trailing: s.theme == mode
                    ? Icon(Icons.check_rounded, color: cs.primary)
                    : null,
                onTap: () => n.patch((x) => x.copyWith(theme: mode)),
              ),
          ],
        ),
        const IosSettingsSectionLabel('Text size'),
        IosSettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  const IosSettingsIcon(
                    icon: Icons.format_size_rounded,
                    background: IosSettingsAccents.purple,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Message Text Size',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 17,
                            color: cs.onSurface,
                          ),
                    ),
                  ),
                  Text(
                    '${(s.fontScale * 100).round()}%',
                    style: TextStyle(color: IosSettingsLook.status(context), fontSize: 17),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Slider(
                value: s.fontScale.clamp(0.85, 1.35),
                min: 0.85,
                max: 1.35,
                divisions: 10,
                label: '${(s.fontScale * 100).round()}%',
                onChanged: (v) => n.patch((x) => x.copyWith(fontScale: v)),
              ),
            ),
          ],
        ),
        IosSettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Preview: The quick brown fox jumps over the lazy dog.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize:
                          (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) *
                              s.fontScale,
                    ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
