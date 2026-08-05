import 'package:flutter/material.dart';

import '../models/room.dart';

/// Visual identity for DMs, groups, and channels.
abstract final class RoomKindStyle {
  static Color accent(RoomKind kind, ColorScheme scheme) => switch (kind) {
        RoomKind.dm => scheme.primary,
        RoomKind.group => const Color(0xFF0D9488),
        RoomKind.channel => const Color(0xFFD97706),
      };

  static Color softSurface(RoomKind kind, ColorScheme scheme) =>
      accent(kind, scheme).withValues(alpha: 0.10);

  static IconData icon(RoomKind kind) => switch (kind) {
        RoomKind.dm => Icons.person_outline_rounded,
        RoomKind.group => Icons.groups_rounded,
        RoomKind.channel => Icons.campaign_rounded,
      };

  static String shortLabel(RoomKind kind) => switch (kind) {
        RoomKind.dm => 'Chat',
        RoomKind.group => 'Group',
        RoomKind.channel => 'Channel',
      };

  static BorderRadius bubbleRadius(RoomKind kind, {required bool mine}) =>
      switch (kind) {
        RoomKind.dm => BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        RoomKind.group => BorderRadius.circular(14),
        RoomKind.channel => BorderRadius.circular(8),
      };

  static double listStripeWidth(RoomKind kind) => switch (kind) {
        RoomKind.dm => 0,
        RoomKind.group => 3,
        RoomKind.channel => 4,
      };
}

/// Small kind chip for app bars / tiles.
class RoomKindBadge extends StatelessWidget {
  const RoomKindBadge({super.key, required this.kind, this.compact = false});

  final RoomKind kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = RoomKindStyle.accent(kind, scheme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(RoomKindStyle.icon(kind), size: compact ? 11 : 13, color: color),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              RoomKindStyle.shortLabel(kind),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
