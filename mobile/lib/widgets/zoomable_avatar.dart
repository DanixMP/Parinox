import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Avatar that opens a full-screen, pinch-to-zoom viewer on tap.
///
/// Defaults to a circle; pass [borderRadius] for a rounded-rect / squircle look.
class ZoomableAvatar extends StatelessWidget {
  const ZoomableAvatar({
    super.key,
    required this.heroTag,
    this.imageUrl,
    this.radius = 48,
    this.borderRadius,
    this.fallbackLabel,
    this.fallbackIcon,
    this.backgroundColor,
  });

  final String heroTag;
  final String? imageUrl;
  final double radius;
  /// When set, uses a rounded rectangle instead of a circle.
  final double? borderRadius;
  final String? fallbackLabel;
  final IconData? fallbackIcon;
  final Color? backgroundColor;

  bool get _hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get _isRound => borderRadius == null;
  double get _size => radius * 2;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).colorScheme.primaryContainer;
    final fallback = _hasImage
        ? null
        : fallbackIcon != null
            ? Icon(fallbackIcon, size: radius * 0.85)
            : Text(
                (fallbackLabel?.isNotEmpty == true ? fallbackLabel![0] : '?')
                    .toUpperCase(),
                style: TextStyle(fontSize: radius * 0.75),
              );

    final Widget avatar;
    if (_isRound) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: _hasImage ? CachedNetworkImageProvider(imageUrl!) : null,
        child: fallback,
      );
    } else {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius!),
        child: Container(
          width: _size,
          height: _size,
          color: bg,
          alignment: Alignment.center,
          child: _hasImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: _size,
                  height: _size,
                  fit: BoxFit.cover,
                )
              : fallback,
        ),
      );
    }

    return Hero(
      tag: heroTag,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: _isRound
              ? const CircleBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius!),
                ),
          onTap: () => openAvatarViewer(
            context,
            heroTag: heroTag,
            imageUrl: imageUrl,
            fallbackLabel: fallbackLabel,
            fallbackIcon: fallbackIcon,
            backgroundColor: bg,
          ),
          child: avatar,
        ),
      ),
    );
  }
}

void openAvatarViewer(
  BuildContext context, {
  required String heroTag,
  String? imageUrl,
  String? fallbackLabel,
  IconData? fallbackIcon,
  Color? backgroundColor,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => AvatarViewerPage(
        heroTag: heroTag,
        imageUrl: imageUrl,
        fallbackLabel: fallbackLabel,
        fallbackIcon: fallbackIcon,
        backgroundColor: backgroundColor,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class AvatarViewerPage extends StatefulWidget {
  const AvatarViewerPage({
    super.key,
    required this.heroTag,
    this.imageUrl,
    this.fallbackLabel,
    this.fallbackIcon,
    this.backgroundColor,
  });

  final String heroTag;
  final String? imageUrl;
  final String? fallbackLabel;
  final IconData? fallbackIcon;
  final Color? backgroundColor;

  @override
  State<AvatarViewerPage> createState() => _AvatarViewerPageState();
}

class _AvatarViewerPageState extends State<AvatarViewerPage> {
  final _transform = TransformationController();
  bool _scaled = false;

  bool get _hasImage => widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transform.dispose();
    super.dispose();
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    final scale = _transform.value.getMaxScaleOnAxis();
    setState(() => _scaled = scale > 1.05);
  }

  void _resetZoom() {
    _transform.value = Matrix4.identity();
    setState(() => _scaled = false);
  }

  Future<void> _share() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return;
    try {
      await SharePlus.instance.share(ShareParams(uri: Uri.parse(url), text: url));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied')),
      );
    }
  }

  Future<void> _saveOrOpen() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bg = widget.backgroundColor ?? Theme.of(context).colorScheme.primaryContainer;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _scaled ? _resetZoom : () => Navigator.of(context).maybePop(),
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 5,
              onInteractionEnd: _onInteractionEnd,
              child: Center(
                child: Hero(
                  tag: widget.heroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: _hasImage
                        ? CachedNetworkImage(
                            imageUrl: widget.imageUrl!,
                            fit: BoxFit.contain,
                            width: size.width,
                            height: size.height * 0.85,
                            placeholder: (_, __) => SizedBox(
                              width: size.width * 0.4,
                              height: size.width * 0.4,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, __, ___) => _FallbackDisk(
                              size: size.width * 0.55,
                              backgroundColor: bg,
                              label: widget.fallbackLabel,
                              icon: widget.fallbackIcon,
                            ),
                          )
                        : _FallbackDisk(
                            size: size.width * 0.55,
                            backgroundColor: bg,
                            label: widget.fallbackLabel,
                            icon: widget.fallbackIcon,
                          ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          if (_hasImage)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Share',
                      icon: const Icon(Icons.share_outlined, color: Colors.white),
                      onPressed: _share,
                    ),
                    IconButton(
                      tooltip: 'Save / open',
                      icon: const Icon(Icons.download_outlined, color: Colors.white),
                      onPressed: _saveOrOpen,
                    ),
                  ],
                ),
              ),
            ),
          if (_hasImage)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    _scaled ? 'Double-tap area or tap to reset · pinch to zoom' : 'Pinch to zoom',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FallbackDisk extends StatelessWidget {
  const _FallbackDisk({
    required this.size,
    required this.backgroundColor,
    this.label,
    this.icon,
  });

  final double size;
  final Color backgroundColor;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: size * 0.4)
          : Text(
              (label?.isNotEmpty == true ? label![0] : '?').toUpperCase(),
              style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.w600),
            ),
    );
  }
}
