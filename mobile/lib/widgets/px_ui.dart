import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Soft ambient orbs — colors come from [AppPalette], never hardcoded.
class PxAmbientBackground extends StatelessWidget {
  const PxAmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: scheme.surface),
        Positioned(
          top: -80,
          left: -60,
          child: _Blob(size: 260, color: palette.ambientPrimary),
        ),
        Positioned(
          bottom: -100,
          right: -80,
          child: _Blob(size: 320, color: palette.ambientSecondary),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class PxSurfaceCard extends StatelessWidget {
  const PxSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: palette.pinShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: card,
      ),
    );
  }
}

class PxFilterChipBar extends StatelessWidget {
  const PxFilterChipBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == selected;
          return ChoiceChip(
            label: Text(labels[i]),
            selected: active,
            onSelected: (_) => onSelected(i),
            selectedColor: scheme.secondary,
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active ? scheme.onSecondary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
            backgroundColor: scheme.surfaceContainer,
            visualDensity: VisualDensity.compact,
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class PxSearchField extends StatelessWidget {
  const PxSearchField({
    super.key,
    this.controller,
    this.hintText = 'Search…',
    this.onChanged,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          borderSide: BorderSide(color: scheme.secondary, width: 1.5),
        ),
      ),
    );
  }
}
