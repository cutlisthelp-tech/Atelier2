import 'package:flutter/material.dart';

import '../../models/recommendation.dart';
import '../../theme/tokens.dart';
import 'home_screen.dart';

/// Developer-only screen: renders the real HOME result card over content so
/// the glass treatment can be judged. The outfit below is labeled sample
/// data — it was not scored from any real profile or wardrobe.
class DesignPreviewScreen extends StatelessWidget {
  const DesignPreviewScreen({super.key});

  static final OutfitRecommendation _sample =
      OutfitRecommendation.fromJson(const {
    'context': {
      'occasion': 'dinner',
      'place_label': 'Casablanca',
      'weather': {
        'state': 'ok',
        'temperature_c': 22.3,
        'precipitation_mm': 0.0,
        'weather_code': 2,
        'weather_label': 'partly cloudy',
        'wind_kmh': 5.0,
        'observed_at': '2026-08-15T18:00',
      },
    },
    'factors': [
      {
        'name': 'body_fit',
        'base_weight': 18.0,
        'effective_weight': 20.0,
        'active': true,
        'inactive_reason': null,
        'score': 0.8,
        'contribution': 16.0,
      },
      {
        'name': 'proportion',
        'base_weight': 14.0,
        'effective_weight': 15.6,
        'active': true,
        'inactive_reason': null,
        'score': 0.7,
        'contribution': 10.9,
      },
      {
        'name': 'trend',
        'base_weight': 6.0,
        'effective_weight': 0.0,
        'active': false,
        'inactive_reason': 'no trend feed is connected',
        'score': 0.0,
        'contribution': 0.0,
      },
    ],
    'outfits': [
      {
        'strategy': 'best_match',
        'score': 71.1,
        'garments': [
          {
            'id': 'sample-sweater',
            'category': 'sweater',
            'colors': [
              {'name': 'charcoal', 'hex': '#2f3234', 'share': 0.44},
              {'name': 'white', 'hex': '#edefee', 'share': 0.39},
            ],
            'fit': 'oversized',
            'material': null,
            'pattern': 'checked',
          },
          {
            'id': 'sample-jeans',
            'category': 'jeans',
            'colors': [
              {'name': 'blue', 'hex': '#3a5a8c', 'share': 0.66},
            ],
            'fit': 'slim',
            'material': 'denim',
            'pattern': null,
          },
          {
            'id': 'sample-sneakers',
            'category': 'sneakers',
            'colors': [
              {'name': 'light gray', 'hex': '#c9c9c4', 'share': 0.71},
            ],
            'fit': 'regular',
            'material': 'synthetic',
            'pattern': null,
          },
        ],
        'why': [
          'Fit tracks your preference (67% across the pieces).',
          'Two distinct non-neutral colors keep the palette clean.',
          'Denim sits inside its comfortable temperature band for 22.3\u00B0C.',
        ],
      },
      {
        'strategy': 'safer',
        'score': 64.3,
        'garments': [
          {
            'id': 'sample-sweater',
            'category': 'sweater',
            'colors': [
              {'name': 'charcoal', 'hex': '#2f3234', 'share': 0.44},
            ],
            'fit': 'oversized',
            'material': null,
            'pattern': 'checked',
          },
          {
            'id': 'sample-jeans',
            'category': 'jeans',
            'colors': [
              {'name': 'blue', 'hex': '#3a5a8c', 'share': 0.66},
            ],
            'fit': 'slim',
            'material': 'denim',
            'pattern': null,
          },
        ],
        'why': ['Higher occasion fit, less color risk.'],
      },
    ],
    'excluded': {
      'hard_filters': <dynamic>[],
      'unplaceable': <dynamic>[],
      'filters_note': 'No hard filters applied.',
    },
    'shopping': {
      'state': 'CATALOG_NOT_CONNECTED',
      'message': 'No merchant catalog is connected.',
    },
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surfacePrimary,
        title: Text('Design preview', style: AppType.interface),
      ),
      body: Stack(
        children: [
          // Content behind the glass — blur needs something to blur
          // (DESIGN_SYSTEM §1 honest materiality).
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.graphite,
                    AppColors.ink,
                    AppColors.ink,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 90,
                    right: -60,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.spotlightGold
                            .withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 420,
                    left: -80,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.fog.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(AppSpacing.unit * 3),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.unit * 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(AppSpacing.unit),
                ),
                child: Text(
                  'SAMPLE DATA \u2014 developer preview. This outfit was not '
                  'scored from any real profile or wardrobe; it exists only '
                  'so the design can be judged with content on screen.',
                  style: AppType.interface.copyWith(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.unit * 2),
              ResultCard(recommendation: _sample),
              const SizedBox(height: AppSpacing.unit * 3),
            ],
          ),
        ],
      ),
    );
  }
}
