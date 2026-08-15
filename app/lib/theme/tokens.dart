import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Semantic design tokens — docs/DESIGN_SYSTEM.md §2.
/// Code references token roles, never raw hex, so light/dark and
/// accessibility modes can adapt later.
abstract final class AppColors {
  static const ink = Color(0xFF16161B);
  static const graphite = Color(0xFF2A2A31);
  static const bone = Color(0xFFF5F3EE);
  static const fog = Color(0xFFC7C6C9);
  static const spotlightGold = Color(0xFFB99A5B);
  static const signalRed = Color(0xFFC0453A);

  // Semantic roles (dark canvas is the default).
  static const surfacePrimary = ink;
  static const surfaceElevated = graphite;
  static const textPrimary = bone;
  static const textSecondary = fog;
  static const accentSignature = spotlightGold;
  static const error = signalRed;
  static final borderSubtle = fog.withValues(alpha: 0.08);
}

/// Three type roles with deliberately different jobs (§2).
/// System fonts for now; licensed faces are bundled in a later phase.
abstract final class AppType {
  static const display = TextStyle(fontFamily: 'serif');
  static const interface = TextStyle();
  static const data = TextStyle(fontFamily: 'monospace');
}

/// 8pt grid with 4pt subdivisions (§2).
abstract final class AppSpacing {
  static const unit = 8.0;
  static const half = 4.0;
  static const minTapTarget = 44.0;
}

/// The single glass definition (DESIGN_SYSTEM §1): glass is reserved for a
/// small number of primary surfaces, and every one of them uses this —
/// never hand-rolled blur values per screen.
abstract final class AppGlass {
  static const blurSigma = 22.0;

  /// Nav bar: darker, over content that scrolls beneath it.
  static const navBase = AppColors.surfacePrimary;
  static const navAlpha = 0.66;

  /// Cards: elevated graphite, slightly more transparent.
  static const cardBase = AppColors.surfaceElevated;
  static const cardAlpha = 0.55;
}

/// A glass surface: blur over what sits behind it, tinted, subtly bordered.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.base = AppGlass.cardBase,
    this.alpha = AppGlass.cardAlpha,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color base;
  final double alpha;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: base.withValues(alpha: alpha),
      border: border ?? Border.all(color: AppColors.borderSubtle),
      borderRadius: borderRadius,
    );
    final content = Container(
      decoration: decoration,
      padding: padding,
      child: child,
    );
    final blur = BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: AppGlass.blurSigma,
        sigmaY: AppGlass.blurSigma,
      ),
      child: content,
    );
    final radius = borderRadius;
    return radius == null
        ? ClipRect(child: blur)
        : ClipRRect(borderRadius: radius, child: blur);
  }
}

ThemeData buildAtelierTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surfacePrimary,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surfacePrimary,
      surfaceContainerHighest: AppColors.surfaceElevated,
      primary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}
