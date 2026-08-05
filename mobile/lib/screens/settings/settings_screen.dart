import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/media_url.dart';
import '../../widgets/zoomable_avatar.dart';
import '../profile/edit_profile_screen.dart';
import 'about_screen.dart';
import 'appearance_settings_screen.dart';
import 'auto_download_settings_screen.dart';
import 'chat_settings_screen.dart';
import 'chat_theme_settings_screen.dart';
import 'customize_settings_screen.dart';
import 'ios_settings_chrome.dart';
import 'notifications_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'storage_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).valueOrNull;
    final user = auth?.user;
    final settings = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final api = ref.watch(apiProvider);
    final avatarUrl = MediaUrl.resolve(api.baseUrl, user?.avatarPath);

    return IosSettingsScaffold(
      title: 'Settings',
      largeTitle: true,
      children: [
        if (user != null)
          IosSettingsGroup(
            children: [
              IosSettingsProfileTile(
                name: user.displayName,
                subtitle: 'Account, profile, and more',
                avatar: ZoomableAvatar(
                  heroTag: 'settings-avatar-${user.id}',
                  imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                  radius: 28,
                  fallbackLabel: user.displayName,
                ),
                onTap: () => _push(context, const EditProfileScreen()),
              ),
            ],
          ),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.lock_outline_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'Privacy and Security',
              value: privacyLabel(settings.lastSeen),
              onTap: () => _push(context, const PrivacySettingsScreen()),
            ),
            IosSettingsTile(
              icon: Icons.notifications_rounded,
              iconBackground: IosSettingsAccents.red,
              title: 'Notifications and Sounds',
              value: settings.notifyPrivate ? 'On' : 'Off',
              onTap: () => _push(context, const NotificationsSettingsScreen()),
            ),
            IosSettingsTile(
              icon: Icons.chat_bubble_rounded,
              iconBackground: IosSettingsAccents.green,
              title: 'Chat Settings',
              value: settings.enterToSend ? 'Enter to send' : null,
              onTap: () => _push(context, const ChatSettingsScreen()),
            ),
          ],
        ),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.download_rounded,
              iconBackground: IosSettingsAccents.indigo,
              title: 'Auto-Download Media',
              onTap: () => _push(context, const AutoDownloadSettingsScreen()),
            ),
            IosSettingsTile(
              icon: Icons.storage_rounded,
              iconBackground: IosSettingsAccents.gray,
              title: 'Storage and Cache',
              value: settings.useLessData ? 'Data saver' : null,
              onTap: () => _push(context, const StorageSettingsScreen()),
            ),
            IosSettingsSwitchTile(
              icon: Icons.data_saver_on_rounded,
              iconBackground: IosSettingsAccents.teal,
              title: 'Data Saver',
              value: settings.useLessData,
              onChanged: (v) => ref.read(settingsProvider.notifier).patch(
                    (s) => s.copyWith(useLessData: v),
                  ),
            ),
          ],
        ),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.tune_rounded,
              iconBackground: IosSettingsAccents.purple,
              title: 'Customize',
              value: designSystemLabel(settings.designSystem),
              onTap: () => _push(context, const CustomizeSettingsScreen()),
            ),
            IosSettingsTile(
              icon: Icons.wallpaper_rounded,
              iconBackground: IosSettingsAccents.pink,
              title: 'Chat Themes',
              value: settings.activeChatTheme.name,
              onTap: () => _push(context, const ChatThemeSettingsScreen()),
            ),
            IosSettingsTile(
              icon: Icons.palette_rounded,
              iconBackground: IosSettingsAccents.orange,
              title: 'Appearance',
              value: themeLabel(settings.theme),
              onTap: () => _push(context, const AppearanceSettingsScreen()),
            ),
          ],
        ),
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.mic_rounded,
              iconBackground: IosSettingsAccents.green,
              title: 'Noise Cancellation',
              value: settings.noiseCancellation,
              onChanged: (v) => ref.read(settingsProvider.notifier).patch(
                    (s) => s.copyWith(noiseCancellation: v),
                  ),
            ),
          ],
        ),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.info_rounded,
              iconBackground: IosSettingsAccents.gray,
              title: 'About Parinox',
              value: '0.1.0',
              onTap: () => _push(context, const AboutScreen()),
            ),
          ],
        ),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.restart_alt_rounded,
              iconBackground: IosSettingsAccents.orange,
              title: 'Reset All Settings',
              showChevron: false,
              onTap: () => _confirmReset(context, ref),
            ),
            IosSettingsTile(
              icon: Icons.logout_rounded,
              iconBackground: IosSettingsAccents.red,
              title: 'Sign Out',
              showChevron: false,
              onTap: () => _confirmLogout(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset settings?'),
        content: const Text(
          'This restores privacy, notifications, auto-download, and appearance defaults. Your account is not affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(settingsProvider.notifier).reset();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings reset to defaults')),
        );
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }
}
