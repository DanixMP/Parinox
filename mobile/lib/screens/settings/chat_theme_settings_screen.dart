import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/app_settings.dart';
import '../../models/chat_theme.dart';
import '../../providers/settings_provider.dart';
import '../../theme/chat_style.dart';
import '../../utils/wallpaper_file.dart';
import '../../widgets/island_back_button.dart';
import 'ios_settings_chrome.dart';

/// Premade + custom chat colors and wallpapers.
class ChatThemeSettingsScreen extends ConsumerWidget {
  const ChatThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final n = ref.read(settingsProvider.notifier);
    final active = s.activeChatTheme;

    return Scaffold(
      backgroundColor: IosSettingsLook.pageBg(context),
      appBar: AppBar(
        title: const Text('Chat Themes'),
        backgroundColor: IosSettingsLook.pageBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IslandBackButton.maybeOf(context),
        leadingWidth: IslandBackButton.leadingWidthOf(context),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'chat_theme_create',
        onPressed: () => _openEditor(context, ref, base: active),
        icon: const Icon(Icons.add),
        label: const Text('Custom theme'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const IosSettingsFooter(
            'Bubble chrome follows your design system. Pick a premade pack or build your own colors and wallpaper.',
          ),
          const SizedBox(height: 8),
          const IosSettingsSectionLabel('Premade'),
          IosSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    for (final theme in ChatThemePresets.all)
                      ChatThemePreviewCard(
                        theme: theme,
                        system: s.designSystem,
                        selected: s.chatThemeId == theme.id,
                        onTap: () => n.patch((x) => x.copyWith(chatThemeId: theme.id)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (s.customChatThemes.isNotEmpty) ...[
            const IosSettingsSectionLabel('Your themes'),
            IosSettingsGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      for (final theme in s.customChatThemes)
                        ChatThemePreviewCard(
                          theme: theme,
                          system: s.designSystem,
                          selected: s.chatThemeId == theme.id,
                          onTap: () => n.patch((x) => x.copyWith(chatThemeId: theme.id)),
                          onLongPress: () => _customActions(context, ref, theme),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const IosSettingsSectionLabel('Quick wallpaper'),
          const IosSettingsFooter(
            'Updates wallpaper on the active theme without changing bubble colors.',
          ),
          IosSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in ChatWallpapers.presets)
                      ChoiceChip(
                        label: Text(ChatWallpapers.label(id)),
                        selected: active.wallpaperId == id,
                        onSelected: (_) => _patchActiveWallpaper(ref, s, id),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Upload image'),
                      onPressed: () async {
                        final id = await pickAndStoreWallpaper();
                        if (id == null) return;
                        _patchActiveWallpaper(ref, s, id);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          IosSettingsGroup(
            children: [
              IosSettingsTile(
                icon: Icons.tune_rounded,
                iconBackground: IosSettingsAccents.purple,
                title: active.isCustom
                    ? 'Edit “${active.name}”'
                    : 'Customize from “${active.name}”',
                onTap: () => _openEditor(
                  context,
                  ref,
                  base: active,
                  editExisting: active.isCustom,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _patchActiveWallpaper(WidgetRef ref, AppSettings s, String wallpaperId) {
    final active = s.activeChatTheme;
    if (active.isCustom) {
      final updated = s.customChatThemes
          .map((t) => t.id == active.id ? t.copyWith(wallpaperId: wallpaperId) : t)
          .toList();
      ref.read(settingsProvider.notifier).patch(
            (x) => x.copyWith(customChatThemes: updated),
          );
      return;
    }
    final forked = active.copyWith(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: '${active.name} · ${ChatWallpapers.label(wallpaperId)}',
      wallpaperId: wallpaperId,
      isCustom: true,
    );
    ref.read(settingsProvider.notifier).patch(
          (x) => x.copyWith(
            customChatThemes: [...x.customChatThemes, forked],
            chatThemeId: forked.id,
          ),
        );
  }

  Future<void> _customActions(
    BuildContext context,
    WidgetRef ref,
    ChatThemeConfig theme,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'edit') {
      await _openEditor(context, ref, base: theme, editExisting: true);
      return;
    }
    final s = ref.read(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final remaining = s.customChatThemes.where((t) => t.id != theme.id).toList();
    ref.read(settingsProvider.notifier).patch(
          (x) => x.copyWith(
            customChatThemes: remaining,
            chatThemeId: x.chatThemeId == theme.id ? 'classic' : x.chatThemeId,
          ),
        );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    required ChatThemeConfig base,
    bool editExisting = false,
  }) async {
    final result = await Navigator.of(context).push<ChatThemeConfig>(
      MaterialPageRoute(
        builder: (_) => _ChatThemeEditorScreen(
          initial: base,
          editExisting: editExisting && base.isCustom,
        ),
      ),
    );
    if (result == null) return;
    final s = ref.read(settingsProvider).valueOrNull ?? AppSettings.defaults;
    if (editExisting && base.isCustom) {
      final updated = s.customChatThemes
          .map((t) => t.id == result.id ? result : t)
          .toList();
      ref.read(settingsProvider.notifier).patch(
            (x) => x.copyWith(
              customChatThemes: updated,
              chatThemeId: result.id,
            ),
          );
      return;
    }
    ref.read(settingsProvider.notifier).patch(
          (x) => x.copyWith(
            customChatThemes: [...x.customChatThemes, result],
            chatThemeId: result.id,
          ),
        );
  }
}

Future<String?> pickAndStoreWallpaper() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 92,
    maxWidth: 2048,
  );
  if (picked == null) return null;
  final docs = await getApplicationDocumentsDirectory();
  final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
  final destPath = p.join(
    docs.path,
    'wallpapers',
    'wp_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
  final saved = await persistPickedWallpaper(picked.path, destPath);
  if (saved == null || saved.isEmpty) return null;
  return ChatWallpapers.fileId(saved);
}

class _ChatThemeEditorScreen extends ConsumerStatefulWidget {
  const _ChatThemeEditorScreen({
    required this.initial,
    required this.editExisting,
  });

  final ChatThemeConfig initial;
  final bool editExisting;

  @override
  ConsumerState<_ChatThemeEditorScreen> createState() =>
      _ChatThemeEditorScreenState();
}

class _ChatThemeEditorScreenState extends ConsumerState<_ChatThemeEditorScreen> {
  late final TextEditingController _name;
  late final String _id;
  late int _mine;
  late int _mineFg;
  late int _theirs;
  late int _theirsFg;
  late String _wallpaperId;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _id = widget.editExisting
        ? i.id
        : 'custom_${DateTime.now().millisecondsSinceEpoch}';
    _name = TextEditingController(
      text: widget.editExisting ? i.name : '${i.name} custom',
    );
    _mine = i.bubbleMine;
    _mineFg = i.bubbleMineFg;
    _theirs = i.bubbleTheirs;
    _theirsFg = i.bubbleTheirsFg;
    _wallpaperId = i.wallpaperId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ChatThemeConfig get _draft => ChatThemeConfig(
        id: _id,
        name: _name.text.trim().isEmpty ? 'Custom' : _name.text.trim(),
        bubbleMine: _mine,
        bubbleMineFg: _mineFg,
        bubbleTheirs: _theirs,
        bubbleTheirsFg: _theirsFg,
        wallpaperId: _wallpaperId,
        isCustom: true,
      );

  Future<void> _editColor(ValueChanged<int> apply, Color current) async {
    final picked = await showFullColorPicker(context, current);
    if (picked == null) return;
    setState(() => apply(picked.toARGB32()));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final scheme = Theme.of(context).colorScheme;
    final draft = _draft;
    final filePath = ChatWallpapers.filePath(_wallpaperId);

    return Scaffold(
      backgroundColor: IosSettingsLook.pageBg(context),
      appBar: AppBar(
        title: Text(widget.editExisting ? 'Edit Theme' : 'New Theme'),
        backgroundColor: IosSettingsLook.pageBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IslandBackButton.maybeOf(context),
        leadingWidth: IslandBackButton.leadingWidthOf(context),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, draft),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          IosSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 160,
                  child: ChatThemePreviewCard(
                    theme: draft,
                    system: s.designSystem,
                    selected: true,
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
          IosSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const IosSettingsSectionLabel('Your bubble'),
          IosSettingsGroup(
            children: [
              _EditableColorRow(
                label: 'Fill',
                color: Color(_mine),
                onTap: () => _editColor((v) => _mine = v, Color(_mine)),
              ),
              _EditableColorRow(
                label: 'Text',
                color: Color(_mineFg),
                onTap: () => _editColor((v) => _mineFg = v, Color(_mineFg)),
              ),
            ],
          ),
          const IosSettingsSectionLabel('Their bubble'),
          IosSettingsGroup(
            children: [
              _EditableColorRow(
                label: 'Fill',
                color: Color(_theirs),
                onTap: () => _editColor((v) => _theirs = v, Color(_theirs)),
              ),
              _EditableColorRow(
                label: 'Text',
                color: Color(_theirsFg),
                onTap: () => _editColor((v) => _theirsFg = v, Color(_theirsFg)),
              ),
            ],
          ),
          const IosSettingsSectionLabel('Wallpaper'),
          IosSettingsGroup(
            children: [
              if (filePath != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: chatWallpaperFileImage(
                            filePath,
                            fit: BoxFit.cover,
                            errorChild: ColoredBox(
                              color: scheme.surfaceContainer,
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Using uploaded image',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in ChatWallpapers.presets)
                      ChoiceChip(
                        label: Text(ChatWallpapers.label(id)),
                        selected: _wallpaperId == id,
                        onSelected: (_) => setState(() => _wallpaperId = id),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.color_lens_outlined, size: 18),
                      label: const Text('Any color'),
                      onPressed: () async {
                        final c = await showFullColorPicker(
                          context,
                          ChatWallpapers.solidColor(_wallpaperId) ?? Color(_mine),
                        );
                        if (c == null) return;
                        setState(() => _wallpaperId = ChatWallpapers.solidId(c));
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Upload image'),
                      onPressed: () async {
                        final id = await pickAndStoreWallpaper();
                        if (id == null) return;
                        setState(() => _wallpaperId = id);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const IosSettingsFooter(
            'Tap any color row to open the full picker. Upload stores the image on this device.',
          ),
        ],
      ),
    );
  }
}

Future<Color?> showFullColorPicker(BuildContext context, Color current) {
  var draft = current;
  return showDialog<Color>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                pickerColor: draft,
                onColorChanged: (c) => draft = c,
                enableAlpha: true,
                hexInputBar: true,
                labelTypes: const [
                  ColorLabelType.hex,
                  ColorLabelType.rgb,
                  ColorLabelType.hsv,
                ],
                pickerAreaHeightPercent: 0.7,
                displayThumbColor: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, draft),
            child: const Text('Apply'),
          ),
        ],
      );
    },
  );
}

class _EditableColorRow extends StatelessWidget {
  const _EditableColorRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.outline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.labelLarge),
                      Text(
                        hex,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.colorize_rounded, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
