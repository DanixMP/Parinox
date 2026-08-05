import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hux/hux.dart';
import 'package:nes_ui/nes_ui.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';
import '../island_back_button.dart';
import 'ds_button.dart';

/// Scaffold that activates the selected design system’s chrome on every page.
class DsScaffold extends ConsumerWidget {
  const DsScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system =
        ref.watch(settingsProvider).valueOrNull?.designSystem ?? DesignSystem.hux;
    final scheme = Theme.of(context).colorScheme;

    Widget content = Scaffold(
      appBar: appBar,
      body: _DecoratedBody(system: system, child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      extendBody: extendBody,
      backgroundColor: backgroundColor ??
          (system == DesignSystem.nes
              ? scheme.surface
              : Theme.of(context).scaffoldBackgroundColor),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );

    if (system == DesignSystem.nes) {
      content = NesScaffold(body: content);
    }

    return content;
  }
}

class _DecoratedBody extends StatelessWidget {
  const _DecoratedBody({required this.system, required this.child});

  final DesignSystem system;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (system != DesignSystem.nes) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _NesDotGridPainter(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.04),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _NesDotGridPainter extends CustomPainter {
  _NesDotGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 16.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NesDotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// App bar styled per design system.
class DsAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const DsAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.titleSpacing,
    this.bottom,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final double? titleSpacing;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system =
        ref.watch(settingsProvider).valueOrNull?.designSystem ?? DesignSystem.hux;
    final scheme = Theme.of(context).colorScheme;
    final resolvedLeading = leading ??
        (automaticallyImplyLeading ? IslandBackButton.maybeOf(context) : null);

    final bar = AppBar(
      title: title,
      leading: resolvedLeading,
      leadingWidth: resolvedLeading != null ? 60 : null,
      actions: actions,
      automaticallyImplyLeading: false,
      titleSpacing: titleSpacing,
      bottom: bottom,
      elevation: switch (system) {
        DesignSystem.nes => 0,
        DesignSystem.shadcn || DesignSystem.shadcnFlutter => 0,
        DesignSystem.hux => 0,
        _ => null,
      },
      backgroundColor: switch (system) {
        DesignSystem.nes => scheme.surface,
        DesignSystem.moon => scheme.surfaceContainerLow,
        _ => null,
      },
      shape: switch (system) {
        DesignSystem.nes => const Border(
            bottom: BorderSide(color: Color(0xFF212529), width: 3),
          ),
        DesignSystem.shadcn || DesignSystem.shadcnFlutter => Border(
            bottom: BorderSide(color: scheme.outlineVariant),
          ),
        DesignSystem.hux => Border(
            bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
        _ => null,
      },
    );

    if (system == DesignSystem.nes) {
      return PreferredSize(
        preferredSize: preferredSize,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(color: Color(0xFF212529), offset: Offset(0, 3)),
            ],
          ),
          child: bar,
        ),
      );
    }
    return bar;
  }
}

/// FAB that becomes NES / Hux / Material depending on design system.
class DsFab extends ConsumerWidget {
  const DsFab({
    super.key,
    required this.onPressed,
    required this.child,
    this.heroTag,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Object? heroTag;
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system =
        ref.watch(settingsProvider).valueOrNull?.designSystem ?? DesignSystem.hux;
    final scheme = Theme.of(context).colorScheme;

    return switch (system) {
      DesignSystem.nes => NesButton(
          type: NesButtonType.primary,
          onPressed: onPressed,
          child: child,
        ),
      DesignSystem.hux => HuxButton(
          onPressed: onPressed,
          child: child,
        ),
      DesignSystem.shadcn || DesignSystem.shadcnFlutter => DsButton(
          onPressed: onPressed,
          child: child,
        ),
      _ => FloatingActionButton(
          heroTag: heroTag,
          tooltip: tooltip,
          onPressed: onPressed,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: child,
        ),
    };
  }
}

/// Design-system aware bottom sheet helper.
Future<T?> showDsBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
}) {
  final system = ProviderScope.containerOf(context)
          .read(settingsProvider)
          .valueOrNull
          ?.designSystem ??
      DesignSystem.hux;

  if (system == DesignSystem.hux) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: showDragHandle,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: builder,
    );
  }

  if (system == DesignSystem.nes) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          border: const Border(
            top: BorderSide(color: Color(0xFF212529), width: 3),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0xFF212529), offset: Offset(0, -3)),
          ],
        ),
        child: SafeArea(child: builder(ctx)),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: showDragHandle,
    builder: builder,
  );
}
