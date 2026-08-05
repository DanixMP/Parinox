import 'package:flutter/material.dart';

/// Floating “island” back control — pill chrome used across the app.
class IslandBackButton extends StatelessWidget {
  const IslandBackButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Back',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  /// Convenient AppBar leading that only shows when the route can pop.
  static Widget? maybeOf(BuildContext context) {
    if (!Navigator.of(context).canPop()) return null;
    return const IslandBackButton();
  }

  static double? leadingWidthOf(BuildContext context) =>
      Navigator.of(context).canPop() ? 60 : null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.surface.withValues(alpha: 0.92),
        elevation: 0,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: Container(
            width: 44,
            height: 36,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.9)),
              ),
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              size: 26,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// Safe-area overlay for pages that hide the app bar.
class IslandBackOverlay extends StatelessWidget {
  const IslandBackOverlay({
    super.key,
    required this.child,
    this.showBack,
    this.trailing,
  });

  final Widget child;
  final bool? showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? Navigator.of(context).canPop();
    if (!canPop && trailing == null) return child;

    return Stack(
      children: [
        child,
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                if (canPop) const IslandBackButton(),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
