import 'dart:ui';

import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../theme/theme.dart';

class AppNavDestination {
  const AppNavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom navigation that can float, dock, stay minimal, curve, or notch.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.style,
    required this.destinations,
    this.notchController,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final NavBarStyle style;
  final List<AppNavDestination> destinations;
  final NotchBottomBarController? notchController;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.curve,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(style),
        child: switch (style) {
          NavBarStyle.floating => _FloatingNav(
              index: index,
              onChanged: onChanged,
              destinations: destinations,
            ),
          NavBarStyle.docked => _DockedNav(
              index: index,
              onChanged: onChanged,
              destinations: destinations,
            ),
          NavBarStyle.minimal => _MinimalNav(
              index: index,
              onChanged: onChanged,
              destinations: destinations,
            ),
          NavBarStyle.curved => _CurvedNav(
              index: index,
              onChanged: onChanged,
              destinations: destinations,
            ),
          NavBarStyle.notch => _NotchNav(
              index: index,
              onChanged: onChanged,
              destinations: destinations,
              controller: notchController ??
                  NotchBottomBarController(index: index),
            ),
        },
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.index,
    required this.onChanged,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom > 0 ? bottom : 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemW = constraints.maxWidth / destinations.length;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: AppMotion.normal,
                          curve: AppMotion.curve,
                          left: itemW * index + 4,
                          top: 0,
                          bottom: 0,
                          width: itemW - 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < destinations.length; i++)
                              Expanded(
                                child: _NavItem(
                                  destination: destinations[i],
                                  selected: index == i,
                                  onTap: () => onChanged(i),
                                  compact: false,
                                  showPill: false,
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockedNav extends StatelessWidget {
  const _DockedNav({
    required this.index,
    required this.onChanged,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: palette.navBar,
      elevation: 8,
      shadowColor: palette.pinShadow,
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onChanged,
        backgroundColor: palette.navBar,
        animationDuration: AppMotion.normal,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon, color: scheme.onSurfaceVariant),
              selectedIcon: Icon(d.selectedIcon, color: scheme.secondary),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _MinimalNav extends StatelessWidget {
  const _MinimalNav({
    required this.index,
    required this.onChanged,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, bottom > 0 ? bottom : 8),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _NavItem(
                  destination: destinations[i],
                  selected: index == i,
                  onTap: () => onChanged(i),
                  compact: true,
                  showPill: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurvedNav extends StatelessWidget {
  const _CurvedNav({
    required this.index,
    required this.onChanged,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<AppNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CurvedNavigationBar(
      index: index,
      height: 62,
      backgroundColor: Colors.transparent,
      color: scheme.surfaceContainerHigh,
      buttonBackgroundColor: scheme.primary,
      animationDuration: AppMotion.slow,
      animationCurve: AppMotion.curve,
      items: [
        for (var i = 0; i < destinations.length; i++)
          Icon(
            index == i ? destinations[i].selectedIcon : destinations[i].icon,
            size: 24,
            color: index == i ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
      ],
      onTap: onChanged,
    );
  }
}

class _NotchNav extends StatelessWidget {
  const _NotchNav({
    required this.index,
    required this.onChanged,
    required this.destinations,
    required this.controller,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<AppNavDestination> destinations;
  final NotchBottomBarController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (controller.index != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.index != index) controller.jumpTo(index);
      });
    }

    return AnimatedNotchBottomBar(
      notchBottomBarController: controller,
      color: scheme.surfaceContainerHigh,
      notchColor: scheme.primary,
      showLabel: true,
      kIconSize: 22,
      kBottomRadius: 28,
      itemLabelStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
      bottomBarItems: [
        for (final d in destinations)
          BottomBarItem(
            inActiveItem: Icon(d.icon, color: scheme.onSurfaceVariant),
            activeItem: Icon(d.selectedIcon, color: scheme.onPrimary),
            itemLabel: d.label,
          ),
      ],
      onTap: onChanged,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.compact,
    required this.showPill,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final bool showPill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return SoftPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 6),
        decoration: BoxDecoration(
          color: selected && showPill
              ? scheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: AppMotion.normal,
              curve: AppMotion.emphasize,
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                switchInCurve: AppMotion.curve,
                switchOutCurve: AppMotion.curve,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  key: ValueKey(selected),
                  size: compact ? 24 : 22,
                  color: color,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: AppMotion.fast,
                curve: AppMotion.curve,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
