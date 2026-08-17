import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The house button system (2026-08-17 refresh): liquid-glass primary with a
/// subtle Spotlight Gold edge, hairline secondary, quiet ghost. Every variant
/// ships default / pressed / hover / disabled / loading states with a small,
/// soft response — motion in service of feel, never spectacle.
enum AtelierButtonVariant { primary, secondary, ghost }

class AtelierButton extends StatefulWidget {
  const AtelierButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AtelierButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AtelierButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;

  bool get _enabled => onPressed != null && !loading;

  @override
  State<AtelierButton> createState() => _AtelierButtonState();
}

class _AtelierButtonState extends State<AtelierButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    final enabled = widget._enabled;
    final Color border;
    final Color fill;
    final Color text;
    switch (v) {
      case AtelierButtonVariant.primary:
        border = AppColors.goldHairline;
        fill = AppColors.graphite.withValues(alpha: 0.55);
        text = AppColors.textPrimary;
      case AtelierButtonVariant.secondary:
        border = AppColors.borderHairline;
        fill = AppColors.inkDeep.withValues(alpha: 0.35);
        text = AppColors.textPrimary;
      case AtelierButtonVariant.ghost:
        border = Colors.transparent;
        fill = Colors.transparent;
        text = AppColors.textSecondary;
    }

    final label = Row(
      mainAxisSize:
          widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading) ...[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: text.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: AppSpacing.unit),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 17, color: text),
          const SizedBox(width: AppSpacing.unit),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: AppType.interface.copyWith(
              fontSize: 14,
              letterSpacing: 0.4,
              color: text,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return AnimatedScale(
      scale: _pressed && enabled ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.38,
        duration: const Duration(milliseconds: 180),
        child: SizedBox(
          height: AppSpacing.minTapTarget,
          width: widget.fullWidth ? double.infinity : null,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: (h) => setState(() => _pressed = h),
              hoverColor: AppColors.spotlightGold.withValues(alpha: 0.06),
              splashColor: AppColors.spotlightGold.withValues(alpha: 0.10),
              highlightColor: AppColors.spotlightGold.withValues(alpha: 0.06),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                  boxShadow: v == AtelierButtonVariant.primary && enabled
                      ? [
                          BoxShadow(
                            color: AppColors.spotlightGold.withValues(
                              alpha: _pressed ? 0.22 : 0.10,
                            ),
                            blurRadius: _pressed ? 22 : 14,
                            offset: const Offset(0, 6),
                          ),
                          const BoxShadow(
                            color: Color(0x660B0B0E),
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ]
                      : null,
                  gradient: v == AtelierButtonVariant.primary
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.bone.withValues(alpha: 0.10),
                            AppColors.bone.withValues(alpha: 0.02),
                          ],
                        )
                      : null,
                ),
                child: Center(child: label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
