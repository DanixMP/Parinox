import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/media_url.dart';

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
  String? _localAvatarFile;
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
    setState(() => _localAvatarFile = file.path);
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
      if (_localAvatarFile != null) {
        await api.uploadAvatar(_localAvatarFile!);
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
        _localAvatarFile = null;
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
    final remoteAvatar = MediaUrl.resolve(api.baseUrl, _avatarPath);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: _localAvatarFile != null
                            ? FileImage(File(_localAvatarFile!))
                            : (remoteAvatar.isNotEmpty
                                ? CachedNetworkImageProvider(remoteAvatar)
                                : null),
                        child: (_localAvatarFile == null && remoteAvatar.isEmpty)
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: Theme.of(context).colorScheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _saving ? null : _pickAvatar,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_avatarPath != null || _localAvatarFile != null)
                  TextButton(
                    onPressed: _saving ? null : _removeAvatar,
                    child: const Text('Remove photo'),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  enabled: !_saving,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  maxLength: 280,
                  enabled: !_saving,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
    );
  }
}
