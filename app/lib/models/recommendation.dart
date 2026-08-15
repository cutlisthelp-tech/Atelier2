/// Typed Phase 3 recommendation results.
library;

import 'analysis.dart';

class WeatherReport {
  const WeatherReport({
    required this.state,
    this.temperatureC,
    this.precipitationMm,
    this.weatherLabel,
    this.windKmh,
    this.observedAt,
    this.message,
  });

  /// "ok" or "WEATHER_UNAVAILABLE".
  final String state;
  final double? temperatureC;
  final double? precipitationMm;
  final String? weatherLabel;
  final double? windKmh;
  final String? observedAt;
  final String? message;

  factory WeatherReport.fromJson(Map<String, dynamic> json) => WeatherReport(
        state: json['state'] as String,
        temperatureC: (json['temperature_c'] as num?)?.toDouble(),
        precipitationMm: (json['precipitation_mm'] as num?)?.toDouble(),
        weatherLabel: json['weather_label'] as String?,
        windKmh: (json['wind_kmh'] as num?)?.toDouble(),
        observedAt: json['observed_at'] as String?,
        message: json['message'] as String?,
      );
}

class FactorReport {
  const FactorReport({
    required this.name,
    required this.baseWeight,
    required this.effectiveWeight,
    required this.active,
    required this.inactiveReason,
    required this.score,
    required this.contribution,
  });

  final String name;
  final double baseWeight;
  final double effectiveWeight;
  final bool active;
  final String? inactiveReason;
  final double score;
  final double contribution;

  factory FactorReport.fromJson(Map<String, dynamic> json) => FactorReport(
        name: json['name'] as String,
        baseWeight: (json['base_weight'] as num).toDouble(),
        effectiveWeight: (json['effective_weight'] as num).toDouble(),
        active: json['active'] as bool,
        inactiveReason: json['inactive_reason'] as String?,
        score: (json['score'] as num).toDouble(),
        contribution: (json['contribution'] as num).toDouble(),
      );
}

class GarmentRef {
  const GarmentRef({
    required this.id,
    required this.category,
    required this.colors,
    required this.fit,
    required this.material,
    required this.pattern,
  });

  final String id;
  final String category;
  final List<GarmentColor> colors;
  final String? fit;
  final String? material;
  final String? pattern;

  factory GarmentRef.fromJson(Map<String, dynamic> json) => GarmentRef(
        id: json['id'] as String,
        category: json['category'] as String,
        colors: (json['colors'] as List<dynamic>)
            .map((c) => GarmentColor.fromJson(c as Map<String, dynamic>))
            .toList(),
        fit: json['fit'] as String?,
        material: json['material'] as String?,
        pattern: json['pattern'] as String?,
      );
}

class ScoredOutfit {
  const ScoredOutfit({
    required this.strategy,
    required this.score,
    required this.garments,
    required this.why,
  });

  final String strategy;
  final double score;
  final List<GarmentRef> garments;
  final List<String> why;

  factory ScoredOutfit.fromJson(Map<String, dynamic> json) => ScoredOutfit(
        strategy: json['strategy'] as String,
        score: (json['score'] as num).toDouble(),
        garments: (json['garments'] as List<dynamic>)
            .map((g) => GarmentRef.fromJson(g as Map<String, dynamic>))
            .toList(),
        why: (json['why'] as List<dynamic>).cast<String>(),
      );
}

class OutfitRecommendation {
  const OutfitRecommendation({
    required this.occasion,
    required this.placeLabel,
    required this.weather,
    required this.factors,
    required this.outfits,
    required this.hardFilterExclusions,
    required this.unplaceable,
    required this.filtersNote,
    required this.shoppingState,
    required this.shoppingMessage,
  });

  final String occasion;
  final String placeLabel;
  final WeatherReport weather;
  final List<FactorReport> factors;
  final List<ScoredOutfit> outfits;
  final List<Map<String, dynamic>> hardFilterExclusions;
  final List<Map<String, dynamic>> unplaceable;
  final String filtersNote;
  final String shoppingState;
  final String shoppingMessage;

  factory OutfitRecommendation.fromJson(Map<String, dynamic> json) {
    final context = json['context'] as Map<String, dynamic>;
    final excluded = json['excluded'] as Map<String, dynamic>;
    final shopping = json['shopping'] as Map<String, dynamic>;
    return OutfitRecommendation(
      occasion: context['occasion'] as String,
      placeLabel: context['place_label'] as String,
      weather: WeatherReport.fromJson(context['weather'] as Map<String, dynamic>),
      factors: (json['factors'] as List<dynamic>)
          .map((f) => FactorReport.fromJson(f as Map<String, dynamic>))
          .toList(),
      outfits: (json['outfits'] as List<dynamic>)
          .map((o) => ScoredOutfit.fromJson(o as Map<String, dynamic>))
          .toList(),
      hardFilterExclusions: (excluded['hard_filters'] as List<dynamic>)
          .cast<Map<String, dynamic>>(),
      unplaceable: (excluded['unplaceable'] as List<dynamic>)
          .cast<Map<String, dynamic>>(),
      filtersNote: excluded['filters_note'] as String,
      shoppingState: shopping['state'] as String,
      shoppingMessage: shopping['message'] as String,
    );
  }
}

sealed class RecommendOutcome {
  const RecommendOutcome();
}

class RecommendSuccess extends RecommendOutcome {
  const RecommendSuccess(this.recommendation);
  final OutfitRecommendation recommendation;
}

class RecommendFailure extends RecommendOutcome {
  const RecommendFailure({required this.code, required this.message});
  final String code;
  final String message;
}
