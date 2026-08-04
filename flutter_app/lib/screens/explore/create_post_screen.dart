import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _caption = TextEditingController();
  final _picker = ImagePicker();
  String? _imagePath;
  bool _posting = false;
  String? _error;

  Future<void> _pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (file == null) return;
    setState(() {
      _imagePath = file.path;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_imagePath == null) {
      setState(() => _error = 'Pick an image first');
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      final post = await ref.read(apiProvider).createPost(
            imagePath: _imagePath!,
            caption: _caption.text.trim(),
          );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      Navigator.of(context).pop(post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        actions: [
          TextButton(
            onPressed: _posting ? null : _submit,
            child: _posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Share'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _posting ? null : _pick,
                child: _imagePath == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 48),
                            SizedBox(height: 8),
                            Text('Tap to choose photo'),
                          ],
                        ),
                      )
                    : Image.file(File(_imagePath!), fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            decoration: const InputDecoration(
              labelText: 'Caption',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            maxLength: 500,
            enabled: !_posting,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
