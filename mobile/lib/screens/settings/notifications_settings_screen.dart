import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import 'ios_settings_chrome.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final n = ref.read(settingsProvider.notifier);

    return IosSettingsScaffold(
      title: 'Notifications and Sounds',
      children: [
        const IosSettingsSectionLabel('Message notifications'),
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.person_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'Private Chats',
              value: s.notifyPrivate,
              onChanged: (v) => n.patch((x) => x.copyWith(notifyPrivate: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.groups_rounded,
              iconBackground: IosSettingsAccents.green,
              title: 'Groups',
              value: s.notifyGroups,
              onChanged: (v) => n.patch((x) => x.copyWith(notifyGroups: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.campaign_rounded,
              iconBackground: IosSettingsAccents.orange,
              title: 'Channels',
              value: s.notifyChannels,
              onChanged: (v) => n.patch((x) => x.copyWith(notifyChannels: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.alternate_email_rounded,
              iconBackground: IosSettingsAccents.purple,
              title: 'Mentions',
              value: s.notifyMentions,
              onChanged: (v) => n.patch((x) => x.copyWith(notifyMentions: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.call_rounded,
              iconBackground: IosSettingsAccents.teal,
              title: 'Calls',
              value: s.notifyCalls,
              onChanged: (v) => n.patch((x) => x.copyWith(notifyCalls: v)),
            ),
          ],
        ),
        const IosSettingsSectionLabel('Style'),
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.preview_rounded,
              iconBackground: IosSettingsAccents.indigo,
              title: 'Message Preview',
              value: s.notificationPreview,
              onChanged: (v) => n.patch((x) => x.copyWith(notificationPreview: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.volume_up_rounded,
              iconBackground: IosSettingsAccents.pink,
              title: 'Sound',
              value: s.soundEnabled,
              onChanged: (v) => n.patch((x) => x.copyWith(soundEnabled: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.vibration_rounded,
              iconBackground: IosSettingsAccents.gray,
              title: 'Vibrate',
              value: s.vibrationEnabled,
              onChanged: (v) => n.patch((x) => x.copyWith(vibrationEnabled: v)),
            ),
          ],
        ),
        const IosSettingsFooter(
          'Mentions always notify when you are @mentioned, even if group alerts are off.',
        ),
      ],
    );
  }
}
