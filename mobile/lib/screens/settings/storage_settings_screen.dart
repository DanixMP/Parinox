import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import 'ios_settings_chrome.dart';

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  int? _cacheBytes;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  Future<void> _refreshSize() async {
    final bytes = await ref.read(localCacheProvider).estimatedCacheBytes();
    if (!mounted) return;
    setState(() => _cacheBytes = bytes);
  }

  String _fmt(int? bytes) {
    if (bytes == null) return 'Calculating…';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cache?'),
        content: const Text(
          'Cached messages and images will be removed from this device. Chats stay on the server.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _clearing = true);
    try {
      await ref.read(localCacheProvider).clearAll();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _refreshSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final n = ref.read(settingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return IosSettingsScaffold(
      title: 'Storage and Cache',
      children: [
        IosSettingsGroup(
          children: [
            IosSettingsTile(
              icon: Icons.folder_rounded,
              iconBackground: IosSettingsAccents.blue,
              title: 'Local Cache',
              value: _fmt(_cacheBytes),
              showChevron: false,
              trailing: _clearing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _clearCache,
                      child: Text('Clear', style: TextStyle(color: cs.primary)),
                    ),
            ),
          ],
        ),
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.auto_delete_rounded,
              iconBackground: IosSettingsAccents.orange,
              title: 'Auto-Clear Cache',
              value: s.autoClearCache,
              onChanged: (v) => n.patch((x) => x.copyWith(autoClearCache: v)),
            ),
            if (s.autoClearCache)
              IosSettingsTile(
                icon: Icons.calendar_today_rounded,
                iconBackground: IosSettingsAccents.gray,
                title: 'Keep Cache For',
                value: '${s.cacheKeepDays} days',
                onTap: () async {
                  final days = await showModalBottomSheet<int>(
                    context: context,
                    showDragHandle: true,
                    backgroundColor: IosSettingsLook.cardBg(context),
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final d in [7, 14, 30, 60, 90])
                            ListTile(
                              title: Text('$d days'),
                              trailing: d == s.cacheKeepDays ? const Icon(Icons.check) : null,
                              onTap: () => Navigator.pop(ctx, d),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (days != null) {
                    await n.patch((x) => x.copyWith(cacheKeepDays: days));
                  }
                },
              ),
          ],
        ),
        if (s.autoClearCache)
          IosSettingsFooter(
            'Remove unused cache older than ${s.cacheKeepDays} days.',
          ),
        const SizedBox(height: 8),
        IosSettingsGroup(
          children: [
            IosSettingsSwitchTile(
              icon: Icons.data_saver_on_rounded,
              iconBackground: IosSettingsAccents.teal,
              title: 'Data Saver',
              value: s.useLessData,
              onChanged: (v) => n.patch((x) => x.copyWith(useLessData: v)),
            ),
            IosSettingsSwitchTile(
              icon: Icons.compress_rounded,
              iconBackground: IosSettingsAccents.indigo,
              title: 'Compress Media',
              value: s.mediaCompression,
              onChanged: (v) => n.patch((x) => x.copyWith(mediaCompression: v)),
            ),
          ],
        ),
      ],
    );
  }
}
