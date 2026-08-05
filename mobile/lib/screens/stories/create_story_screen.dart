import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_provider.dart';
import '../../providers/stories_provider.dart';
import '../../widgets/island_back_button.dart';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _picker = ImagePicker();
  Uint8List? _bytes;
  String? _filename;
  bool _isVideo = false;
  bool _posting = false;
  String? _error;

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _bytes = bytes;
      _filename = file.name;
      _isVideo = false;
      _error = null;
    });
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _bytes = bytes;
      _filename = file.name;
      _isVideo = true;
      _error = null;
    });
  }

  Future<void> _share() async {
    if (_bytes == null) {
      setState(() => _error = 'Pick a photo or video first');
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).createStory(
            _bytes!,
            isVideo: _isVideo,
            filename: _filename,
          );
      await ref.read(storiesFeedProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New story'),
        leading: IslandBackButton.maybeOf(context),
        leadingWidth: IslandBackButton.leadingWidthOf(context),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _posting ? null : _share,
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
            aspectRatio: 9 / 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _bytes == null
                    ? const Center(child: Text('No media selected'))
                    : _isVideo
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam, size: 48),
                                SizedBox(height: 8),
                                Text('Video selected'),
                              ],
                            ),
                          )
                        : Image.memory(_bytes!, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _posting ? null : _pickImage,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Photo'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _posting ? null : _pickVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Video'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Text(
            'Stories expire after 24 hours.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
