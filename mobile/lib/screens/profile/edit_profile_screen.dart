import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/media_url.dart';
import '../../widgets/island_back_button.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _picker = ImagePicker();
  String? _avatarPath;
  String? _bannerPath;
  String? _username;
  Uint8List? _localAvatarBytes;
  Uint8List? _localBannerBytes;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await ref.read(apiProvider).me();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = me.displayName;
        _bioCtrl.text = me.bio;
        _avatarPath = me.avatarPath;
        _bannerPath = me.bannerPath;
        _username = me.username;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _localAvatarBytes = bytes);
  }

  Future<void> _pickBanner() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 1200,
      imageQuality: 88,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _localBannerBytes = bytes);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Display name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      await api.updateMe(displayName: name, bio: _bioCtrl.text.trim());
      if (_localAvatarBytes != null) {
        await api.uploadAvatar(_localAvatarBytes!);
      }
      if (_localBannerBytes != null) {
        await api.uploadBanner(_localBannerBytes!);
      }
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Save failed: $e';
      });
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).clearAvatar();
      if (!mounted) return;
      setState(() {
        _avatarPath = null;
        _localAvatarBytes = null;
        _saving = false;
      });
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _removeBanner() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).clearBanner();
      if (!mounted) return;
      setState(() {
        _bannerPath = null;
        _localBannerBytes = null;
        _saving = false;
      });
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final cs = Theme.of(context).colorScheme;
    final remoteAvatar = MediaUrl.resolve(api.baseUrl, _avatarPath);
    final remoteBanner = MediaUrl.resolve(api.baseUrl, _bannerPath);

    ImageProvider? avatarImage;
    if (_localAvatarBytes != null) {
      avatarImage = MemoryImage(_localAvatarBytes!);
    } else if (remoteAvatar.isNotEmpty) {
      avatarImage = CachedNetworkImageProvider(remoteAvatar);
    }

    ImageProvider? bannerImage;
    if (_localBannerBytes != null) {
      bannerImage = MemoryImage(_localBannerBytes!);
    } else if (remoteBanner.isNotEmpty) {
      bannerImage = CachedNetworkImageProvider(remoteBanner);
    }

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IslandBackButton.maybeOf(context),
        leadingWidth: IslandBackButton.leadingWidthOf(context),
        automaticallyImplyLeading: false,
        title: const Text('Edit profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving || _loading ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                minimumSize: const Size(0, 36),
              ),
              child: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // —— Banner + overlapping avatar ——
                SizedBox(
                  height: 210,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 150,
                        child: GestureDetector(
                          onTap: _saving ? null : _pickBanner,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      cs.primary.withValues(alpha: 0.85),
                                      cs.secondary.withValues(alpha: 0.55),
                                      cs.tertiary.withValues(alpha: 0.4),
                                    ],
                                  ),
                                  image: bannerImage != null
                                      ? DecorationImage(
                                          image: bannerImage,
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      cs.shadow.withValues(alpha: 0.05),
                                      cs.shadow.withValues(alpha: 0.35),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 14,
                                bottom: 14,
                                child: _MediaChip(
                                  icon: Icons.photo_camera_back_outlined,
                                  label: bannerImage == null ? 'Add banner' : 'Change banner',
                                  onTap: _saving ? null : _pickBanner,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _saving ? null : _pickAvatar,
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLow,
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 52,
                                  backgroundColor: cs.primaryContainer,
                                  backgroundImage: avatarImage,
                                  child: avatarImage == null
                                      ? Icon(
                                          Icons.person_rounded,
                                          size: 48,
                                          color: cs.onPrimaryContainer,
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cs.surfaceContainerLow,
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                    color: cs.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_username != null)
                        Text(
                          '@$_username',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (_avatarPath != null || _localAvatarBytes != null)
                            TextButton(
                              onPressed: _saving ? null : _removeAvatar,
                              child: const Text('Remove photo'),
                            ),
                          if (_bannerPath != null || _localBannerBytes != null)
                            TextButton(
                              onPressed: _saving ? null : _removeBanner,
                              child: const Text('Remove banner'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Profile details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Display name',
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.badge_outlined, color: cs.onSurfaceVariant),
                              ),
                              textCapitalization: TextCapitalization.words,
                              enabled: !_saving,
                            ),
                            Divider(height: 1, color: cs.outlineVariant),
                            TextField(
                              controller: _bioCtrl,
                              decoration: InputDecoration(
                                labelText: 'Bio',
                                alignLabelWithHint: true,
                                border: InputBorder.none,
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(bottom: 48),
                                  child: Icon(Icons.notes_rounded, color: cs.onSurfaceVariant),
                                ),
                              ),
                              maxLines: 4,
                              maxLength: 280,
                              enabled: !_saving,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your banner sits behind your avatar on your profile. Tap either to change.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: TextStyle(color: cs.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MediaChip extends StatelessWidget {
  const _MediaChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: cs.onSurface),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
