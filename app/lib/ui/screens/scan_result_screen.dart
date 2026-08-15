import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/analysis.dart';
import '../../theme/tokens.dart';

/// Shows whatever a scan honestly produced — real numbers in the Data
/// typeface, or the exact failure state with a way back (DESIGN_SYSTEM §6).
class ScanResultScreen extends StatelessWidget {
  const ScanResultScreen({super.key, required this.outcome, this.capture, this.appearance});

  final ScanOutcome outcome;
  final Uint8List? capture;

  /// Appearance result from the same capture, when a face was usable.
  final AppearanceScanSuccess? appearance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan', style: AppType.interface)),
      body: SafeArea(
        child: switch (outcome) {
          BodyScanSuccess(:final body, :final confidence, :final flags) =>
            _BodyResult(
              body: body,
              confidence: confidence,
              flags: flags,
              capture: capture,
              appearance: appearance,
            ),
          AppearanceScanSuccess(:final color, :final confidence) =>
            _ColorResult(color: color, confidence: confidence),
          GarmentScanSuccess(
            :final garment,
            :final confidence,
            :final flags
          ) =>
            _GarmentResult(
              garment: garment,
              confidence: confidence,
              flags: flags,
              capture: capture,
            ),
          ScanFailure(:final code, :final message) => _Failure(code: code, message: message),
        },
      ),
    );
  }
}

class _BodyResult extends StatelessWidget {
  const _BodyResult({
    required this.body,
    required this.confidence,
    required this.flags,
    required this.capture,
    required this.appearance,
  });

  final BodyProfile body;
  final double confidence;
  final List<String> flags;
  final Uint8List? capture;
  final AppearanceScanSuccess? appearance;

  @override
  Widget build(BuildContext context) {
    final m = body.measurementsCm;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.unit * 3),
      children: [
        Text(
          'Body profile',
          style: AppType.display.copyWith(fontSize: 28, color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.unit),
        _ConfidenceRow(confidence: confidence, flags: flags),
        const SizedBox(height: AppSpacing.unit * 2),
        if (capture != null)
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.unit),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(capture!, fit: BoxFit.cover),
                  CustomPaint(painter: _SkeletonPainter(body.skeleton)),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.unit * 3),
        _Metric('Shoulder', m['shoulder']),
        _Metric('Hip', m['hip']),
        _Metric('Torso', m['torso']),
        _Metric('Leg', m['leg']),
        _Metric('Arm', m['arm']),
        _Metric('Chest', m['chest'], note: 'not measurable from one photo'),
        _Metric('Waist', m['waist'], note: 'not measurable from one photo'),
        const SizedBox(height: AppSpacing.unit * 2),
        _Ratio('Torso : leg', body.proportions['torso_to_leg_ratio']),
        _Ratio('Shoulder : hip', body.proportions['shoulder_to_hip_ratio']),
        _Ratio('Vertical balance', body.proportions['vertical_balance']),
        const SizedBox(height: AppSpacing.unit),
        Text(
          'Shape read: ${body.bodyShape.replaceAll('_', ' ')} · '
          '${body.visibleLandmarks}/33 landmarks visible',
          style: AppType.interface.copyWith(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (appearance != null) ...[
          const SizedBox(height: AppSpacing.unit * 3),
          Text(
            'Color read from this capture',
            style: AppType.display.copyWith(fontSize: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.unit),
          _Line('Undertone', appearance!.color.skinUndertone),
          _Line('Depth', appearance!.color.skinDepth),
          _Line('Contrast', appearance!.color.overallContrast),
          _Line('Season read', appearance!.color.season),
          const SizedBox(height: AppSpacing.unit),
          Wrap(
            spacing: AppSpacing.unit,
            runSpacing: AppSpacing.unit,
            children: [
              for (final s in appearance!.color.palette)
                Tooltip(
                  message: '${s.name} ${s.hex}',
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(
                        0xFF000000 | int.parse(s.hex.replaceFirst('#', ''), radix: 16),
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.half),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ColorResult extends StatelessWidget {
  const _ColorResult({required this.color, required this.confidence});

  final ColorProfile color;
  final double confidence;

  Color _parse(String hex) {
    final v = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.unit * 3),
      children: [
        Text(
          'Color profile',
          style: AppType.display.copyWith(fontSize: 28, color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.unit),
        _ConfidenceRow(confidence: confidence, flags: const []),
        const SizedBox(height: AppSpacing.unit * 2),
        _Line('Undertone', color.skinUndertone),
        _Line('Depth', color.skinDepth),
        _Line('Contrast', color.overallContrast),
        _Line('Season read', color.season),
        const SizedBox(height: AppSpacing.unit * 3),
        Text(
          'PALETTE',
          style: AppType.data.copyWith(fontSize: 11, letterSpacing: 1.4, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.unit),
        Wrap(
          spacing: AppSpacing.unit * 1.5,
          runSpacing: AppSpacing.unit * 1.5,
          children: [
            for (final s in color.palette)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _parse(s.hex),
                      borderRadius: BorderRadius.circular(AppSpacing.half),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.half),
                  SizedBox(
                    width: 72,
                    child: Text(
                      s.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.interface.copyWith(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    s.hex,
                    style: AppType.data.copyWith(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _GarmentResult extends StatelessWidget {
  const _GarmentResult({
    required this.garment,
    required this.confidence,
    required this.flags,
    this.capture,
  });

  final GarmentProfile garment;
  final double confidence;
  final List<String> flags;
  final Uint8List? capture;

  Color _parse(String hex) {
    final v = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.unit * 3),
      children: [
        Text(
          'Garment read',
          style: AppType.display.copyWith(fontSize: 28, color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.unit),
        _ConfidenceRow(confidence: confidence, flags: flags),
        const SizedBox(height: AppSpacing.unit * 2),
        if (capture != null)
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.unit),
              child: Image.memory(capture!, fit: BoxFit.cover),
            ),
          ),
        const SizedBox(height: AppSpacing.unit * 3),
        _Line(
          'Category',
          garment.category.value ?? 'Unknown',
          note: garment.category.value == null
              ? 'not confidently recognizable in this photo'
              : null,
        ),
        _Line('Pattern', garment.pattern.value ?? 'Unknown',
            note: garment.pattern.value == null
                ? 'not reliably visible in this photo'
                : null),
        _Line('Fit', garment.fit.value ?? 'Unknown',
            note: garment.fit.value == null
                ? 'not reliably visible in this photo'
                : null),
        _Line('Material', garment.material.value ?? 'Unknown',
            note: garment.material.value == null
                ? 'not reliably visible in this photo'
                : null),
        const SizedBox(height: AppSpacing.unit * 3),
        Text(
          'COLORS',
          style: AppType.data.copyWith(
              fontSize: 11, letterSpacing: 1.4, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.unit),
        if (garment.colors.isEmpty)
          Text(
            'No colors could be read from this photo.',
            style: AppType.interface.copyWith(fontSize: 13, color: AppColors.textSecondary),
          )
        else
          Wrap(
            spacing: AppSpacing.unit * 1.5,
            runSpacing: AppSpacing.unit * 1.5,
            children: [
              for (final c in garment.colors)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _parse(c.hex),
                        borderRadius: BorderRadius.circular(AppSpacing.half),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.half),
                    SizedBox(
                      width: 72,
                      child: Text(
                        c.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.interface.copyWith(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                    Text(
                      '${c.hex} · ${(c.share * 100).round()}%',
                      style: AppType.data.copyWith(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.unit * 2),
        Text(
          garment.colorsSource == 'segmentation'
              ? 'Colors read from the clothing region of this photo.'
              : 'Colors read from the center of this photo — no worn clothing region was detected.',
          style: AppType.interface.copyWith(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.code, required this.message});

  final String code;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This one didn’t work',
              style: AppType.display.copyWith(fontSize: 24, color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.unit * 2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.interface.copyWith(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.unit * 2),
            Text(
              code,
              style: AppType.data.copyWith(fontSize: 12, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({required this.confidence, required this.flags});

  final double confidence;
  final List<String> flags;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    return Row(
      children: [
        Text(
          'CONFIDENCE $pct%',
          style: AppType.data.copyWith(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.unit),
        Expanded(
          child: LinearProgressIndicator(
            value: confidence,
            minHeight: 3,
            backgroundColor: AppColors.surfaceElevated,
            color: flags.contains('LOW_CONFIDENCE')
                ? AppColors.error
                : AppColors.textSecondary,
          ),
        ),
        if (flags.contains('LOW_CONFIDENCE')) ...[
          const SizedBox(width: AppSpacing.unit),
          Text(
            'LOW CONFIDENCE',
            style: AppType.data.copyWith(fontSize: 11, color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.valueCm, {this.note});

  final String label;
  final double? valueCm;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.half),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppType.interface.copyWith(fontSize: 15, color: AppColors.textSecondary),
                ),
                if (note != null)
                  Text(
                    note!,
                    style: AppType.interface.copyWith(fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            valueCm == null ? '—' : '${valueCm!.toStringAsFixed(1)} cm',
            style: AppType.data.copyWith(fontSize: 16, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Ratio extends StatelessWidget {
  const _Ratio(this.label, this.value);

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.half),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppType.interface.copyWith(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Text(
            value == null ? '—' : value!.toStringAsFixed(3),
            style: AppType.data.copyWith(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.half),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppType.interface.copyWith(fontSize: 15, color: AppColors.textSecondary),
                ),
                if (note != null)
                  Text(
                    note!,
                    style: AppType.interface.copyWith(fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          Text(
            value.toUpperCase(),
            style: AppType.data.copyWith(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Draws the real returned skeleton — normalized landmark coordinates
/// mapped onto the captured frame.
class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter(this.points);

  final List<SkeletonPoint> points;

  static const _bones = [
    [11, 12], [11, 13], [13, 15], [12, 14], [14, 16],
    [11, 23], [12, 24], [23, 24],
    [23, 25], [25, 27], [24, 26], [26, 28],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bonePaint = Paint()
      ..color = AppColors.bone.withValues(alpha: 0.85)
      ..strokeWidth = 2;
    final jointPaint = Paint()..color = AppColors.spotlightGold;
    final faded = Paint()
      ..color = AppColors.fog.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    for (final bone in _bones) {
      final a = points[bone[0]];
      final b = points[bone[1]];
      final strong = a.visibility > 0.5 && b.visibility > 0.5;
      canvas.drawLine(
        Offset(a.x * size.width, a.y * size.height),
        Offset(b.x * size.width, b.y * size.height),
        strong ? bonePaint : faded,
      );
    }
    for (final p in points) {
      if (p.visibility <= 0.5) continue;
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), 3, jointPaint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) => oldDelegate.points != points;
}
