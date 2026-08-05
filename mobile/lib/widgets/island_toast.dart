import 'package:flutter/material.dart';

/// Small floating island toast (e.g. “Copied”) — replaces bulky SnackBars.
OverlayEntry? _activeIslandToast;

void showIslandToast(
  BuildContext context, {
  required String message,
  IconData icon = Icons.check_rounded,
  Duration duration = const Duration(milliseconds: 1400),
}) {
  _activeIslandToast?.remove();
  _activeIslandToast = null;

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Positioned(
        left: 0,
        right: 0,
        bottom: bottom + 72,
        child: IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - t)),
                  child: child,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: ShapeDecoration(
                    color: cs.inverseSurface.withValues(alpha: 0.94),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: cs.onInverseSurface.withValues(alpha: 0.08),
                      ),
                    ),
                    shadows: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: cs.onInverseSurface),
                      const SizedBox(width: 8),
                      Text(
                        message,
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              color: cs.onInverseSurface,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _activeIslandToast = entry;
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    if (_activeIslandToast == entry) {
      entry.remove();
      _activeIslandToast = null;
    }
  });
}
