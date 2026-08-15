/// Typed results for the Phase 1 analysis pipelines.
///
/// A scan either produces a real result with confidence, or an exact §12
/// failure state — never a substitute (docs/PRODUCT_SPEC.md §12).
library;

class SkeletonPoint {
  const SkeletonPoint({required this.x, required this.y, required this.visibility});

  final double x;
  final double y;
  final double visibility;

  factory SkeletonPoint.fromJson(Map<String, dynamic> json) => SkeletonPoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        visibility: (json['visibility'] as num).toDouble(),
      );
}

class Swatch {
  const Swatch({required this.name, required this.hex});

  final String name;
  final String hex;

  factory Swatch.fromJson(Map<String, dynamic> json) =>
      Swatch(name: json['name'] as String, hex: json['hex'] as String);
}

class BodyProfile {
  const BodyProfile({
    required this.measurementsCm,
    required this.proportions,
    required this.bodyShape,
    required this.skeleton,
    required this.visibleLandmarks,
  });

  /// Keys: height_input, shoulder, hip, torso, leg, arm, chest, waist.
  /// chest/waist are null by design — a single 2D capture cannot support them.
  final Map<String, double?> measurementsCm;
  final Map<String, double?> proportions;
  final String bodyShape;
  final List<SkeletonPoint> skeleton;
  final int visibleLandmarks;

  factory BodyProfile.fromJson(Map<String, dynamic> json) {
    double? opt(Object? v) => v == null ? null : (v as num).toDouble();
    return BodyProfile(
      measurementsCm: (json['measurements_cm'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, opt(v))),
      proportions: (json['proportions'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, opt(v))),
      bodyShape: json['body_shape'] as String,
      skeleton: (json['skeleton'] as List<dynamic>)
          .map((p) => SkeletonPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      visibleLandmarks: json['visible_landmarks'] as int,
    );
  }
}

class ColorProfile {
  const ColorProfile({
    required this.skinUndertone,
    required this.skinDepth,
    required this.overallContrast,
    required this.season,
    required this.palette,
  });

  final String skinUndertone;
  final String skinDepth;
  final String overallContrast;
  final String season;
  final List<Swatch> palette;

  factory ColorProfile.fromJson(Map<String, dynamic> json) => ColorProfile(
        skinUndertone: json['skin_undertone'] as String,
        skinDepth: json['skin_depth'] as String,
        overallContrast: json['overall_contrast'] as String,
        season: json['season'] as String,
        palette: (json['palette'] as List<dynamic>)
            .map((s) => Swatch.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

/// Everything a scan call can honestly return.
sealed class ScanOutcome {
  const ScanOutcome();
}

class BodyScanSuccess extends ScanOutcome {
  const BodyScanSuccess({
    required this.body,
    required this.confidence,
    required this.flags,
  });

  final BodyProfile body;
  final double confidence;
  final List<String> flags;
}

class AppearanceScanSuccess extends ScanOutcome {
  const AppearanceScanSuccess({
    required this.color,
    required this.confidence,
    required this.flags,
  });

  final ColorProfile color;
  final double confidence;
  final List<String> flags;
}

class ScanFailure extends ScanOutcome {
  const ScanFailure({required this.code, required this.message});

  /// A §12 failure-state code, e.g. NO_PERSON, POOR_IMAGE, NETWORK_ERROR.
  final String code;
  final String message;
}

/// One garment attribute from the Phase 2 pipeline. A null [value] is the
/// honest "Unknown" — the model was not confident enough to name it.
class GarmentAttribute {
  const GarmentAttribute({required this.value, required this.confidence});

  final String? value;
  final double confidence;

  factory GarmentAttribute.fromJson(Map<String, dynamic> json) =>
      GarmentAttribute(
        value: json['value'] as String?,
        confidence: (json['confidence'] as num).toDouble(),
      );
}

class GarmentColor {
  const GarmentColor({
    required this.name,
    required this.hex,
    required this.share,
  });

  final String name;
  final String hex;
  final double share;

  factory GarmentColor.fromJson(Map<String, dynamic> json) => GarmentColor(
        name: json['name'] as String,
        hex: json['hex'] as String,
        share: (json['share'] as num).toDouble(),
      );
}

class GarmentProfile {
  const GarmentProfile({
    required this.category,
    required this.colors,
    required this.colorsSource,
    required this.pattern,
    required this.fit,
    required this.material,
  });

  final GarmentAttribute category;
  final List<GarmentColor> colors;

  /// "segmentation" (clothing mask) or "center_weighted" (flat-lay fallback).
  final String colorsSource;
  final GarmentAttribute pattern;
  final GarmentAttribute fit;
  final GarmentAttribute material;

  factory GarmentProfile.fromJson(Map<String, dynamic> json) => GarmentProfile(
        category: GarmentAttribute.fromJson(
            json['category'] as Map<String, dynamic>),
        colors: (json['colors'] as List<dynamic>)
            .map((c) => GarmentColor.fromJson(c as Map<String, dynamic>))
            .toList(),
        colorsSource: json['colors_source'] as String,
        pattern: GarmentAttribute.fromJson(
            json['pattern'] as Map<String, dynamic>),
        fit: GarmentAttribute.fromJson(json['fit'] as Map<String, dynamic>),
        material: GarmentAttribute.fromJson(
            json['material'] as Map<String, dynamic>),
      );
}

class GarmentScanSuccess extends ScanOutcome {
  const GarmentScanSuccess({
    required this.garment,
    required this.confidence,
    required this.flags,
  });

  final GarmentProfile garment;
  final double confidence;
  final List<String> flags;
}

class ModelStatus {
  const ModelStatus({
    required this.name,
    required this.task,
    required this.runtime,
    required this.hardware,
    required this.installed,
    required this.loaded,
  });

  final String name;
  final String task;
  final String runtime;
  final String hardware;
  final bool installed;
  final bool loaded;

  factory ModelStatus.fromJson(Map<String, dynamic> json) => ModelStatus(
        name: json['name'] as String,
        task: json['task'] as String,
        runtime: json['runtime'] as String,
        hardware: json['hardware'] as String,
        installed: json['installed'] as bool,
        loaded: json['loaded'] as bool,
      );
}
