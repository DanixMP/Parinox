import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import 'ios_settings_chrome.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final n = ref.read(settingsProvider.notifier);

    return IosSettingsScaffold(
      title: 'Privacy and Security',
      children: [
        const IosSettingsSectionLabel('Who can see my personal info'),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.schedule_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'Last Seen & Online',
              value: privacyLabel(s.lastSeen),
              onTap: () => _pickPrivacy(
                context,
                'Last seen & online',
                s.lastSeen,
                (v) => n.patch((x) => x.copyWith(lastSeen: v)),
              ),
            ),
            IosSettingsTile(
              icon: Icons.photo_rounded,
              iconBackground: IosSettingsAccents.purple,
              title: 'Profile Photos',
              value: privacyLabel(s.profilePhoto),
              onTap: () => _pickPrivacy(
                context,
                'Profile photos',
                s.profilePhoto,
                (v) => n.patch((x) => x.copyWith(profilePhoto: v)),
              ),
            ),
            IosSettingsTile(
              icon: Icons.notes_rounded,
              iconBackground: IosSettingsAccents.teal,
              title: 'Bio',
              value: privacyLabel(s.bio),
              onTap: () => _pickPrivacy(
                context,
                'Bio',
                s.bio,
                (v) => n.patch((x) => x.copyWith(bio: v)),
              ),
            ),
            IosSettingsTile(
              icon: Icons.shortcut_rounded,
              iconBackground: IosSettingsAccents.orange,
              title: 'Forwarded Messages',
              value: privacyLabel(s.forwardedMessages),
              onTap: () => _pickPrivacy(
                context,
                'Forwarded messages',
                s.forwardedMessages,
                (v) => n.patch((x) => x.copyWith(forwardedMessages: v)),
              ),
            ),
          ],
        ),
        const IosSettingsSectionLabel('Messages'),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.mail_outline_rounded,
              iconBackground: IosSettingsAccents.green,
              title: 'Who Can Message Me',
              value: whoCanMessageLabel(s.whoCanMessage),
              onTap: () async {
                final next = await _pickWhoCanMessage(context, s.whoCanMessage);
                if (next != null) await n.patch((x) => x.copyWith(whoCanMessage: next));
              },
            ),
            IosSettingsSwitchTile(
              icon: Icons.done_all_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'Read Receipts',
              value: s.readReceipts,
              onChanged: (v) => n.patch((x) => x.copyWith(readReceipts: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.more_horiz_rounded,
              iconBackground: IosSettingsAccents.gray,
              title: 'Typing Indicators',
              value: s.typingIndicators,
              onChanged: (v) => n.patch((x) => x.copyWith(typingIndicators: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.link_rounded,
              iconBackground: IosSettingsAccents.indigo,
              title: 'Link Previews',
              value: s.linkPreviews,
              onChanged: (v) => n.patch((x) => x.copyWith(linkPreviews: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.group_add_rounded,
              iconBackground: IosSettingsAccents.teal,
              title: 'Invite Links',
              value: s.inviteViaLink,
              onChanged: (v) => n.patch((x) => x.copyWith(inviteViaLink: v)),
            ),
          ],
        ),
        const IosSettingsFooter(
          'If read receipts are off, you won’t send or receive them. Group chats are unchanged.',
        ),
        const SizedBox(height: 8),
        const IosSettingsSectionLabel('Blocked'),
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.block_rounded,
              iconBackground: IosSettingsAccents.red,
              title: 'Blocked Users',
              value: 'None',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No blocked users yet')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickPrivacy(
    BuildContext context,
    String title,
    PrivacyVisibility current,
    ValueChanged<PrivacyVisibility> onChanged,
  ) async {
    final next = await showModalBottomSheet<PrivacyVisibility>(
      context: context,
      showDragHandle: true,
      backgroundColor: IosSettingsLook.cardBg(context),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final v in PrivacyVisibility.values)
              ListTile(
                title: Text(privacyLabel(v)),
                trailing: v == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    );
    if (next != null) onChanged(next);
  }

  Future<WhoCanMessage?> _pickWhoCanMessage(
    BuildContext context,
    WhoCanMessage current,
  ) {
    return showModalBottomSheet<WhoCanMessage>(
      context: context,
      showDragHandle: true,
      backgroundColor: IosSettingsLook.cardBg(context),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in WhoCanMessage.values)
              ListTile(
                title: Text(whoCanMessageLabel(v)),
                trailing: v == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    );
  }
}
