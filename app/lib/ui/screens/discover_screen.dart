import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// DISCOVER — an editorial section that is honest about having no catalog.
/// The exact §12 state stays visible ("No catalog connected."); the layout
/// carries the design without ever pretending products exist.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        children: [
          Text(
            'DISCOVER',
            style: AppType.caption.copyWith(
              fontSize: 10,
              letterSpacing: 2.4,
              color: AppColors.spotlightGold,
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(
            'Your next wardrobe\nstarts with real products.',
            style: AppType.displayXL.copyWith(
              fontSize: 34,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 3),
          GlassSurface(
            padding: const EdgeInsets.all(AppSpacing.unit * 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No catalog connected.',
                  style: AppType.headline.copyWith(
                    fontSize: 22,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.unit),
                Text(
                  'Atelier only shows real products from licensed catalogs. '
                  'None is linked yet, so there is nothing to discover — and '
                  'nothing fake to fill the gap.',
                  style: AppType.interface.copyWith(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.unit * 2),
                Row(
                  children: [
                    _Pledge('No imaginary products.'),
                    const SizedBox(width: AppSpacing.unit * 2),
                    _Pledge('No fake prices.'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 3),
          // Editorial texture: a quiet strip of the campaign world, purely
          // ambient — never presented as shoppable product.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.asset(
                'assets/editorial/scene_04.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pledge extends StatelessWidget {
  const _Pledge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppColors.spotlightGold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.half),
        Text(
          text,
          style: AppType.data.copyWith(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
