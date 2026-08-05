import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import 'ios_settings_chrome.dart';

class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final n = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return IosSettingsScaffold(
      title: 'Chat Settings',
      children: [
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.keyboard_return_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'Send with Enter',
              value: s.enterToSend,
              onChanged: (v) => n.patch((x) => x.copyWith(enterToSend: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.compress_rounded,
              iconBackground: IosSettingsAccents.orange,
              title: 'Compress Media',
              value: s.mediaCompression,
              onChanged: (v) => n.patch((x) => x.copyWith(mediaCompression: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.link_rounded,
              iconBackground: IosSettingsAccents.indigo,
              title: 'Link Previews',
              value: s.linkPreviews,
              onChanged: (v) => n.patch((x) => x.copyWith(linkPreviews: v)),
            ),
          ],
        ),
        const IosSettingsFooter(
          'Send with Enter uses Shift+Enter for a new line. Compress media sends faster with slightly lower quality.',
        ),
        const SizedBox(height: 8),
        const IosSettingsSectionLabel('Text size'),
        IosSettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  IosSettingsIcon(
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
      ],
    );
  }
}
