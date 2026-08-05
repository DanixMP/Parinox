import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import 'ios_settings_chrome.dart';

class AutoDownloadSettingsScreen extends ConsumerWidget {
  const AutoDownloadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final n = ref.read(settingsProvider.notifier);

    return IosSettingsScaffold(
      title: 'Auto-Download Media',
      children: [
        const IosSettingsFooter(
          'Choose which media downloads automatically when you open a chat.',
        ),
        const SizedBox(height: 8),
        const IosSettingsSectionLabel('Photos'),
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.wifi_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'Using Wi‑Fi',
              value: s.autoDlPhotosWifi,
              onChanged: (v) => n.patch((x) => x.copyWith(autoDlPhotosWifi: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.signal_cellular_alt_rounded,
              iconBackground: IosSettingsAccents.green,
              title: 'Using Mobile Data',
              value: s.autoDlPhotosMobile,
              onChanged: (v) => n.patch((x) => x.copyWith(autoDlPhotosMobile: v)),
            ),
          ],
        ),
        const IosSettingsSectionLabel('Videos'),
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.wifi_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'Using Wi‑Fi',
              value: s.autoDlVideosWifi,
              onChanged: (v) => n.patch((x) => x.copyWith(autoDlVideosWifi: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.signal_cellular_alt_rounded,
              iconBackground: IosSettingsAccents.green,
              title: 'Using Mobile Data',
              value: s.autoDlVideosMobile,
              onChanged: (v) => n.patch((x) => x.copyWith(autoDlVideosMobile: v)),
            ),
          ],
        ),
        const IosSettingsSectionLabel('Files and voice'),
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.wifi_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'Using Wi‑Fi',
              value: s.autoDlFilesWifi,
              onChanged: (v) => n.patch((x) => x.copyWith(autoDlFilesWifi: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.signal_cellular_alt_rounded,
              iconBackground: IosSettingsAccents.green,
              title: 'Using Mobile Data',
              value: s.autoDlFilesMobile,
              onChanged: (v) => n.patch((x) => x.copyWith(autoDlFilesMobile: v)),
            ),
          ],
        ),
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.photo_library_rounded,
              iconBackground: IosSettingsAccents.pink,
              title: 'Save to Gallery',
              value: s.saveToGallery,
              onChanged: (v) => n.patch((x) => x.copyWith(saveToGallery: v)),
            ),
          ],
        ),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.restart_alt_rounded,
              iconBackground: IosSettingsAccents.orange,
              title: 'Reset Auto-Download Defaults',
              showChevron: false,
              onTap: () => n.patch(
                (x) => x.copyWith(
                  autoDlPhotosWifi: true,
                  autoDlPhotosMobile: true,
                  autoDlVideosWifi: true,
                  autoDlVideosMobile: false,
                  autoDlFilesWifi: false,
                  autoDlFilesMobile: false,
                  saveToGallery: false,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
