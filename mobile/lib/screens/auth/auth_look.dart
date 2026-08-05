import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Auth / onboarding chrome — colors only from [ColorScheme].
abstract final class AuthLook {
  static const cardRadius = 12.0;
  static const fieldRadius = 10.0;
  static const pillRadius = 999.0;
  static const tileRadius = 18.0;
  static const maxWidth = 420.0;

  static ColorScheme scheme(BuildContext context) =>
      Theme.of(context).colorScheme;

  static TextStyle brandLogo(BuildContext context) {
    final cs = scheme(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
      letterSpacing: -0.6,
      height: 1.1,
    );
  }

  static TextStyle heroTitle(BuildContext context) {
    final cs = scheme(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
      height: 1.15,
      letterSpacing: -0.8,
    );
  }

  static TextStyle sectionTitle(BuildContext context, {double size = 26}) {
    final cs = scheme(context);
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
      height: 1.2,
      letterSpacing: -0.5,
    );
  }

  static TextStyle title(BuildContext context, {double size = 16}) {
    final cs = scheme(context);
    return Theme.of(context).textTheme.titleMedium!.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        );
  }

  static TextStyle muted(BuildContext context, {double size = 12}) {
    final cs = scheme(context);
    return Theme.of(context).textTheme.bodySmall!.copyWith(
          fontSize: size,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        );
  }

  static TextStyle link(BuildContext context, {double size = 13}) {
    final cs = scheme(context);
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: size,
          color: cs.primary,
          fontWeight: FontWeight.w700,
        );
  }

  static BoxDecoration card(BuildContext context) {
    final cs = scheme(context);
    return BoxDecoration(
      color: cs.surface,
      border: Border.all(color: cs.outlineVariant),
      borderRadius: BorderRadius.circular(cardRadius),
    );
  }

  static InputDecoration fieldDecoration(
    BuildContext context, {
    required String hint,
    Widget? suffix,
  }) {
    final cs = scheme(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(fieldRadius),
      borderSide: BorderSide(color: cs.outlineVariant),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: muted(context, size: 13),
      filled: true,
      fillColor: cs.surfaceContainerLow,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: suffix,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: BorderSide(color: cs.primary, width: 1.4),
      ),
    );
  }

  static ButtonStyle primaryButton(BuildContext context) {
    final cs = scheme(context);
    return ElevatedButton.styleFrom(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      disabledBackgroundColor: cs.primary.withValues(alpha: 0.35),
      disabledForegroundColor: cs.onPrimary.withValues(alpha: 0.7),
      elevation: 0,
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(pillRadius),
      ),
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: AuthLook.maxWidth),
      decoration: AuthLook.card(context),
      padding: padding ?? const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: child,
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = AuthLook.scheme(context);
    return Row(
      children: [
        Expanded(child: Divider(color: cs.outlineVariant, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'OR',
            style: AuthLook.muted(context, size: 12).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(child: Divider(color: cs.outlineVariant, thickness: 1)),
      ],
    );
  }
}
