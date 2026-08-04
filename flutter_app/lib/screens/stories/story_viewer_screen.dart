import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/story.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stories_provider.dart';
import '../../services/media_url.dart';

/// Fullscreen tap-through story viewer with per-story progress bars (DESIGN §7).
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
  });

  final List<StoryGroup> groups;
  final int initialGroupIndex;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  static const _storyDuration = Duration(seconds: 5);

  late int _groupIndex;
  late int _storyIndex;
  late AnimationController _progress;
  final Set<int> _marked = {};

  @override
  void initState() {
    super.initState();
    _groupIndex = widget.initialGroupIndex.clamp(0, widget.groups.length - 1);
    _storyIndex = _firstUnseenIndex(_group);
    _progress = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCurrent());
  }

  StoryGroup get _group => widget.groups[_groupIndex];
  StoryItem get _story => _group.stories[_storyIndex];

  int _firstUnseenIndex(StoryGroup g) {
    final i = g.stories.indexWhere((s) => !s.viewed);
    return i >= 0 ? i : 0;
  }

  Future<void> _startCurrent() async {
    _progress
      ..duration = _story.isVideo ? const Duration(seconds: 8) : _storyDuration
      ..reset();
    await _markViewed(_story.id);
    if (!mounted) return;
    _progress.forward();
  }

  Future<void> _markViewed(int id) async {
    if (_marked.contains(id)) return;
    _marked.add(id);
    await ref.read(storiesFeedProvider.notifier).markViewed(id);
  }

  void _pause() => _progress.stop();

  void _resume() {
    if (_progress.status != AnimationStatus.completed) {
      _progress.forward();
    }
  }

  void _next() {
    if (_storyIndex < _group.stories.length - 1) {
      setState(() => _storyIndex++);
      _startCurrent();
      return;
    }
    if (_groupIndex < widget.groups.length - 1) {
      setState(() {
        _groupIndex++;
        _storyIndex = _firstUnseenIndex(_group);
      });
      _startCurrent();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _prev() {
    if (_storyIndex > 0) {
      setState(() => _storyIndex--);
      _startCurrent();
      return;
    }
    if (_groupIndex > 0) {
      setState(() {
        _groupIndex--;
        _storyIndex = _group.stories.length - 1;
      });
      _startCurrent();
      return;
    }
    // Restart current
    _startCurrent();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final mediaUrl = MediaUrl.resolve(api.baseUrl, _story.mediaPath);
    final avatarUrl = MediaUrl.resolve(api.baseUrl, _group.avatarPath);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < w * 0.3) {
            _prev();
          } else {
            _next();
          }
        },
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_story.isVideo)
              const ColoredBox(
                color: Color(0xFF111111),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_outline, color: Colors.white54, size: 64),
                      SizedBox(height: 8),
                      Text('Video story', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            // Progress bars
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < _group.stories.length; i++) ...[
                          if (i > 0) const SizedBox(width: 3),
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _progress,
                              builder: (_, __) {
                                double value;
                                if (i < _storyIndex) {
                                  value = 1;
                                } else if (i > _storyIndex) {
                                  value = 0;
                                } else {
                                  value = _progress.value;
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 2.5,
                                    backgroundColor: Colors.white24,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white24,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl.isEmpty
                              ? Text(
                                  _group.displayName.isNotEmpty
                                      ? _group.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _group.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
