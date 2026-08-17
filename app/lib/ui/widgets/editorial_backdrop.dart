import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The live editorial backdrop — the visual spine of the 2026-08-17 refresh.
///
/// Layered, honestly, per DESIGN_SYSTEM §1: deep gradient base → scrimmed
/// campaign photograph with a very slow Ken Burns drift → two ambient light
/// fields → film grain → legibility scrim. The photograph is real, licensed
/// editorial imagery (see assets/editorial/PROVENANCE.md); it is ambience,
/// never product data, never a user, never a result.
///
/// Continuous motion runs only where a human watches it (web preview and
/// release builds). In widget tests the backdrop renders as a still frame so
/// `pumpAndSettle` never hangs on an infinite ticker.
class EditorialBackdrop extends StatefulWidget {
  const EditorialBackdrop({
    super.key,
    required this.scene,
    this.photoStrength = 0.5,
    this.child,
  });

  /// Asset path of the campaign scene for the current section.
  final String scene;

  /// How strongly the photograph reads through the scrim (0..1).
  final double photoStrength;

  /// Optional content rendered above the backdrop (below the scrim edge).
  final Widget? child;

  /// Continuous drift is for human eyes only; tests get a still frame.
  static bool get live => kIsWeb || kReleaseMode;

  @override
  State<EditorialBackdrop> createState() => _EditorialBackdropState();
}

class _EditorialBackdropState extends State<EditorialBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController? _drift;

  @override
  void initState() {
    super.initState();
    if (EditorialBackdrop.live) {
      _drift = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 26),
      )..repeat(reverse: true);
    } else {
      _drift = null;
    }
  }

  @override
  void dispose() {
    _drift?.dispose();
    super.dispose();
  }

  double get _t => _drift?.value ?? 0.35;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1 — Base: deep charcoal field, never a flat single color.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.inkDeep,
                AppColors.ink,
                AppColors.graphite,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // 2 — Campaign photograph, scrimmed and desaturated, slow drift.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 1100),
          switchInCurve: Curves.easeInOut,
          child: _PhotoLayer(
            key: ValueKey(widget.scene),
            asset: widget.scene,
            strength: widget.photoStrength,
            drift: _drift,
          ),
        ),
        // 3 — Ambient light fields, drifting out of phase.
        if (_drift != null)
          AnimatedBuilder(
            animation: _drift,
            builder: (context, _) => _ambient(_drift.value),
          )
        else
          _ambient(_t),
        // 4 — Film grain, barely there.
        Opacity(
          opacity: 0.05,
          child: Image.asset(
            'assets/editorial/grain.png',
            repeat: ImageRepeat.repeat,
          ),
        ),
        // 5 — Legibility scrim: text always wins over imagery.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.22, 0.55, 0.82, 1.0],
              colors: [
                Color(0xF20B0B0E),
                Color(0x8A0B0B0E),
                Color(0x42101014),
                Color(0x990B0B0E),
                Color(0xF70B0B0E),
              ],
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _ambient(double t) {
    final dx = 40.0 * (t - 0.5);
    return Stack(
      children: [
        Positioned(
          top: -120 + dx,
          right: -140,
          child: _light(AppColors.spotlightGold.withValues(alpha: 0.10), 420),
        ),
        Positioned(
          bottom: -160 - dx,
          left: -160,
          child: _light(AppColors.fog.withValues(alpha: 0.07), 460),
        ),
      ],
    );
  }

  Widget _light(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

class _PhotoLayer extends StatelessWidget {
  const _PhotoLayer({
    super.key,
    required this.asset,
    required this.strength,
    required this.drift,
  });

  final String asset;
  final double strength;
  final AnimationController? drift;

  // Desaturate + sink the photograph into the charcoal canvas.
  static const ColorFilter _grade = ColorFilter.matrix(<double>[
    0.62, 0.32, 0.06, 0, 0,
    0.10, 0.62, 0.10, 0, 0,
    0.08, 0.30, 0.70, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final image = ColorFiltered(
      colorFilter: _grade,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        opacity: AlwaysStoppedAnimation(strength),
      ),
    );
    if (drift == null) {
      // Still frame for tests: a fixed, composed crop.
      return Transform.scale(scale: 1.08, child: image);
    }
    return AnimatedBuilder(
      animation: drift!,
      builder: (context, _) {
        final t = drift!.value; // 0..1..0 over ~26s
        return Transform.scale(
          scale: 1.05 + 0.06 * t,
          alignment: Alignment(0.0, -0.2 + 0.4 * t),
          child: image,
        );
      },
    );
  }
}
