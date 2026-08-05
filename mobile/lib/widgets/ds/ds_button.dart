import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hux/hux.dart';
import 'package:nes_ui/nes_ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/app_settings.dart';
import '../../providers/settings_provider.dart';

/// Design-system aware primary action button.
/// Defaults to Hux; mirrors variant when other systems are selected.
class DsButton extends ConsumerWidget {
  const DsButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = DsButtonVariant.primary,
    this.icon,
    this.expand = false,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final DsButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final system =
        ref.watch(settingsProvider).valueOrNull?.designSystem ?? DesignSystem.hux;
    final enabled = onPressed != null && !loading;

    Widget wrapExpand(Widget w) =>
        expand ? SizedBox(width: double.infinity, child: w) : w;

    return switch (system) {
      DesignSystem.hux || DesignSystem.parinox || DesignSystem.ios => wrapExpand(
          HuxButton(
            onPressed: enabled ? onPressed : null,
            isLoading: loading,
            isDisabled: !enabled,
            icon: icon,
            width: expand ? HuxButtonWidth.expand : null,
            variant: switch (variant) {
              DsButtonVariant.primary => HuxButtonVariant.primary,
              DsButtonVariant.secondary => HuxButtonVariant.secondary,
              DsButtonVariant.outline => HuxButtonVariant.outline,
              DsButtonVariant.ghost => HuxButtonVariant.ghost,
            },
            child: child,
          ),
        ),
      DesignSystem.shadcn || DesignSystem.shadcnFlutter => wrapExpand(
          switch (variant) {
            DsButtonVariant.primary => ShadButton(
                onPressed: enabled ? onPressed : null,
                child: _labelRow(child, icon, loading),
              ),
            DsButtonVariant.secondary => ShadButton.secondary(
                onPressed: enabled ? onPressed : null,
                child: _labelRow(child, icon, loading),
              ),
            DsButtonVariant.outline => ShadButton.outline(
                onPressed: enabled ? onPressed : null,
                child: _labelRow(child, icon, loading),
              ),
            DsButtonVariant.ghost => ShadButton.ghost(
                onPressed: enabled ? onPressed : null,
                child: _labelRow(child, icon, loading),
              ),
          },
        ),
      DesignSystem.nes => wrapExpand(
          NesButton(
            type: switch (variant) {
              DsButtonVariant.primary => NesButtonType.primary,
              DsButtonVariant.secondary => NesButtonType.normal,
              DsButtonVariant.outline => NesButtonType.normal,
              DsButtonVariant.ghost => NesButtonType.normal,
            },
            onPressed: enabled ? onPressed : null,
            child: _labelRow(child, icon, loading),
          ),
        ),
      DesignSystem.moon => wrapExpand(
          FilledButton(
            onPressed: enabled ? onPressed : null,
            style: variant == DsButtonVariant.outline ||
                    variant == DsButtonVariant.ghost
                ? FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: variant == DsButtonVariant.outline
                        ? BorderSide(color: Theme.of(context).colorScheme.outline)
                        : BorderSide.none,
                  )
                : null,
            child: _labelRow(child, icon, loading),
          ),
        ),
    };
  }

  static Widget _labelRow(Widget child, IconData? icon, bool loading) {
    if (loading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (icon == null) return child;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        child,
      ],
    );
  }
}

enum DsButtonVariant { primary, secondary, outline, ghost }
