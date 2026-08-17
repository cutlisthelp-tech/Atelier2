import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Semantic design tokens — docs/DESIGN_SYSTEM.md §2 (2026-08-17 luxury
/// refresh). Code references token roles, never raw hex, so light/dark and
/// accessibility modes can adapt later.
abstract final class AppColors {
  static const ink = Color(0xFF16161B);
  static const inkDeep = Color(0xFF0B0B0E);
  static const graphite = Color(0xFF2A2A31);
  static const bone = Color(0xFFF5F3EE);
  static const fog = Color(0xFFC7C6C9);
  static const mist = Color(0xFF96959B);
  static const spotlightGold = Color(0xFFB99A5B);
  static const signalRed = Color(0xFFC0453A);

  // Semantic roles (dark canvas is the default).
  static const surfacePrimary = ink;
  static const surfaceElevated = graphite;
  static const textPrimary = bone;
  static const textSecondary = fog;
  static const textTertiary = mist;
  static const accentSignature = spotlightGold;
  static const error = signalRed;
  static final borderSubtle = fog.withValues(alpha: 0.08);
  static final borderHairline = fog.withValues(alpha: 0.14);
  static final goldHairline = spotlightGold.withValues(alpha: 0.35);
}

/// Type roles with deliberately different jobs (§2): editorial serif for
/// display moments, quiet grotesk for interface, monospace for real numbers.
abstract final class AppType {
  static const display = TextStyle(fontFamily: 'serif');
  static const displayXL = TextStyle(
    fontFamily: 'serif',
    fontSize: 44,
    height: 1.04,
    letterSpacing: -0.5,
  );
  static const headline = TextStyle(
    fontFamily: 'serif',
    fontSize: 24,
    height: 1.15,
    letterSpacing: 0.1,
  );
  static const interface = TextStyle();
  static const caption = TextStyle(fontSize: 11, letterSpacing: 1.8);
  static const data = TextStyle(fontFamily: 'monospace');
}

/// 8pt grid with 4pt subdivisions (§2).
abstract final class AppSpacing {
  static const unit = 8.0;
  static const half = 4.0;
  static const minTapTarget = 44.0;
  static const cardRadius = 20.0;
}

/// The single glass definition (DESIGN_SYSTEM §1): glass is reserved for a
/// small number of primary surfaces, and every one of them uses this —
/// never hand-rolled blur values per screen. The 2026-08-17 refresh layers
/// the material honestly: blur → tint → internal top highlight → hairline
/// border → depth shadow, so surfaces read as real glass over the live
/// backdrop, never as "container + opacity".
abstract final class AppGlass {
  static const blurSigma = 22.0;

  /// Nav bar: darker, over content that scrolls beneath it.
  static const navBase = AppColors.surfacePrimary;
  static const navAlpha = 0.66;

  /// Cards: elevated graphite, slightly more transparent.
  static const cardBase = AppColors.surfaceElevated;
  static const cardAlpha = 0.55;
}

/// A glass surface: blur over what sits behind it, tinted, subtly bordered,
/// with an internal highlight and depth shadow.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.base = AppGlass.cardBase,
    this.alpha = AppGlass.cardAlpha,
    this.border,
    this.highlight = true,
    this.depth = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color base;
  final double alpha;
  final BoxBorder? border;
  final bool highlight;
  final bool depth;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ??
        BorderRadius.circular(AppSpacing.cardRadius);
    final decoration = BoxDecoration(
      color: base.withValues(alpha: alpha),
      border: border ?? Border.all(color: AppColors.borderSubtle),
      borderRadius: radius,
      gradient: highlight
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x14F5F3EE),
                Color(0x05F5F3EE),
                Color(0x00F5F3EE),
              ],
              stops: [0.0, 0.28, 1.0],
            )
          : null,
      boxShadow: depth
          ? [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ]
          : null,
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
    return ClipRRect(borderRadius: radius, child: blur);
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
