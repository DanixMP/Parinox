import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../widgets/island_back_button.dart';

/// Shared iOS Settings–style chrome (grouped inset lists).
abstract final class IosSettingsLook {
  static const groupRadius = 12.0;
  static const iconRadius = 8.0;
  static const iconSize = 29.0;
  static const horizontalInset = 16.0;

  static Color pageBg(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  static Color cardBg(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color divider(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color chevron(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.45);

  static Color status(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
}

/// Standard settings page shell with grouped-list background.
class IosSettingsScaffold extends StatelessWidget {
  const IosSettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.largeTitle = false,
  });

  final String title;
  final List<Widget> children;
  final bool largeTitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: IosSettingsLook.pageBg(context),
      appBar: AppBar(
        backgroundColor: IosSettingsLook.pageBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: largeTitle ? null : Text(title),
        centerTitle: false,
        leading: IslandBackButton.maybeOf(context),
        leadingWidth: IslandBackButton.leadingWidthOf(context),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          IosSettingsLook.horizontalInset,
          0,
          IosSettingsLook.horizontalInset,
          40,
        ),
        children: [
          if (largeTitle) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -0.6,
                    ),
              ),
            ),
          ],
          ...children,
        ],
      ),
    );
  }
}

class IosSettingsSectionLabel extends StatelessWidget {
  const IosSettingsSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: IosSettingsLook.status(context),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

class IosSettingsFooter extends StatelessWidget {
  const IosSettingsFooter(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IosSettingsLook.status(context),
              height: 1.35,
            ),
      ),
    );
  }
}

/// Rounded grouped card of settings rows.
class IosSettingsGroup extends StatelessWidget {
  const IosSettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: IosSettingsLook.cardBg(context),
        borderRadius: BorderRadius.circular(IosSettingsLook.groupRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 60),
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: IosSettingsLook.divider(context),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class IosSettingsIcon extends StatelessWidget {
  const IosSettingsIcon({
    super.key,
    required this.icon,
    required this.background,
    this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: IosSettingsLook.iconSize,
      height: IosSettingsLook.iconSize,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(IosSettingsLook.iconRadius),
      ),
      child: Icon(
        icon,
        size: 18,
        color: foreground ?? Colors.white,
      ),
    );
  }
}

/// Navigation / value / toggle row matching iOS Settings.
class IosSettingsTile extends StatelessWidget {
  const IosSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconBackground,
    this.leading,
    this.value,
    this.onTap,
    this.trailing,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconBackground;
  final Widget? leading;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lead = leading ??
        (icon != null
            ? IosSettingsIcon(
                icon: icon!,
                background: iconBackground ?? cs.primary,
              )
            : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              if (lead != null) ...[
                lead,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w400,
                            fontSize: 17,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: IosSettingsLook.status(context),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    value!,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: IosSettingsLook.status(context),
                          fontSize: 17,
                        ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (showChevron && onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: IosSettingsLook.chevron(context),
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class IosSettingsSwitchTile extends StatelessWidget {
  const IosSettingsSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.iconBackground,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            IosSettingsIcon(
              icon: icon!,
              background: iconBackground ?? cs.primary,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 17,
                        color: cs.onSurface,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IosSettingsLook.status(context),
                        ),
                  ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: cs.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Profile row for the root Settings screen.
class IosSettingsProfileTile extends StatelessWidget {
  const IosSettingsProfileTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.avatar,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final Widget avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: IosSettingsLook.status(context),
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: IosSettingsLook.chevron(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS-like accent colors for settings squircles (stable across themes).
abstract final class IosSettingsAccents {
  static const orange = Color(0xFFFF9500);
  static const blue = Color(0xFF007AFF);
  static const teal = Color(0xFF5AC8FA);
  static const green = Color(0xFF34C759);
  static const red = Color(0xFFFF3B30);
  static const purple = Color(0xFFAF52DE);
  static const indigo = Color(0xFF5856D6);
  static const pink = Color(0xFFFF2D55);
  static const gray = Color(0xFF8E8E93);
  static const brown = Color(0xFFA2845E);
}
