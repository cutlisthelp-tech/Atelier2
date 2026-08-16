/// Typed Phase 5 size-engine results.
library;

class SizeRegion {
  const SizeRegion({
    required this.region,
    this.measuredCm,
    this.chartCm,
    this.deltaCm,
    required this.status,
    this.note,
  });

  final String region;
  final double? measuredCm;
  final double? chartCm;
  final double? deltaCm;

  /// matched | off | not_measurable | not_provided.
  final String status;
  final String? note;

  factory SizeRegion.fromJson(Map<String, dynamic> json) => SizeRegion(
        region: json['region'] as String,
        measuredCm: (json['measured_cm'] as num?)?.toDouble(),
        chartCm: (json['chart_cm'] as num?)?.toDouble(),
        deltaCm: (json['delta_cm'] as num?)?.toDouble(),
        status: json['status'] as String,
        note: json['note'] as String?,
      );
}

class SizeScore {
  const SizeScore({required this.label, required this.score});

  final String label;
  final double score;

  factory SizeScore.fromJson(Map<String, dynamic> json) => SizeScore(
        label: json['label'] as String,
        score: (json['score'] as num).toDouble(),
      );
}

class SizeRecommendation {
  const SizeRecommendation({
    required this.label,
    required this.score,
    required this.confidence,
    required this.flags,
    required this.fitType,
    required this.brand,
    required this.regions,
    required this.sizes,
    required this.note,
  });

  final String label;
  final double score;
  final double confidence;
  final List<String> flags;
  final String fitType;
  final String brand;
  final List<SizeRegion> regions;
  final List<SizeScore> sizes;
  final String note;

  factory SizeRecommendation.fromJson(Map<String, dynamic> json) =>
      SizeRecommendation(
        label: (json['recommended'] as Map<String, dynamic>)['label'] as String,
        score: ((json['recommended'] as Map<String, dynamic>)['score'] as num)
            .toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        flags: (json['flags'] as List<dynamic>).cast<String>(),
        fitType: json['fit_type'] as String,
        brand: json['brand'] as String,
        regions: (json['regions'] as List<dynamic>)
            .map((r) => SizeRegion.fromJson(r as Map<String, dynamic>))
            .toList(),
        sizes: (json['sizes'] as List<dynamic>)
            .map((s) => SizeScore.fromJson(s as Map<String, dynamic>))
            .toList(),
        note: json['note'] as String,
      );
}

sealed class SizeOutcome {
  const SizeOutcome();
}

class SizeOk extends SizeOutcome {
  const SizeOk(this.recommendation);
  final SizeRecommendation recommendation;
}

class SizeFailure extends SizeOutcome {
  const SizeFailure({required this.code, required this.message});

  /// A §12 failure-state code, e.g. NO_SIZE_CHART, INSUFFICIENT_DATA.
  final String code;
  final String message;
}
