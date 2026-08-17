import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/tryon.dart';
import '../../services/backend_client.dart';
import '../../theme/tokens.dart';
import '../widgets/atelier_button.dart';

/// TRY ON — Choose Photo + Choose Garment → labeled render (DESIGN_SYSTEM §5).
///
/// The method + confidence line from PRODUCT_SPEC §7 is always visible —
/// never hidden in a submenu. Every failure is the exact §12 state, stated
/// plainly. Photos live in memory only; nothing is written to disk.
class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key, required this.backendClient});

  final BackendClient backendClient;

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _person;
  Uint8List? _garment;
  bool _busy = false;
  TryOnOutcome? _outcome;

  Future<void> _pick(bool person, ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (person) {
          _person = bytes;
        } else {
          _garment = bytes;
        }
        _outcome = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'No camera is available on this platform. Pick from files instead.'
                : 'Files can\u2019t be opened on this platform.',
            style: AppType.interface.copyWith(fontSize: 13),
          ),
        ),
      );
    }
  }

  Future<void> _render() async {
    final person = _person;
    final garment = _garment;
    if (person == null || garment == null || _busy) return;
    setState(() {
      _busy = true;
      _outcome = null;
    });
    final outcome = await widget.backendClient.renderTryOn(person, garment);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        children: [
          Text(
            'VIRTUAL TRY-ON',
            style: AppType.caption.copyWith(
              fontSize: 10,
              letterSpacing: 2.4,
              color: AppColors.spotlightGold,
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(
            'Try On',
            style: AppType.displayXL.copyWith(
              fontSize: 38,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.half),
          Text(
            'The studio dresses your photo in the garment. Every render is '
            'labeled with its method and a real confidence — never a claim '
            'of precise physical simulation.',
            style: AppType.interface.copyWith(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 3),
          _SourceTile(
            label: 'PHOTO OF YOU',
            bytes: _person,
            onPick: (s) => _pick(true, s),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          _SourceTile(
            label: 'GARMENT',
            bytes: _garment,
            onPick: (s) => _pick(false, s),
          ),
          const SizedBox(height: AppSpacing.unit * 3),
          SizedBox(
            height: AppSpacing.minTapTarget,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.graphite.withValues(alpha: 0.65),
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(
                  color: _person == null || _garment == null
                      ? AppColors.borderHairline
                      : AppColors.goldHairline,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _person == null || _garment == null ? null : _render,
              child: Text(
                _busy ? 'Rendering — this takes a few seconds…' : 'Render try-on',
                style: AppType.interface.copyWith(fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          if (_busy)
            const _Skeleton()
          else if (_outcome case TryOnOk(:final result))
            TryOnResultView(result: result, person: _person!)
          else if (_outcome case TryOnFailure(:final code, :final message))
            _Failure(code: code, message: message),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.label, this.bytes, required this.onPick});

  final String label;
  final Uint8List? bytes;
  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppType.caption.copyWith(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: AppColors.spotlightGold,
                ),
              ),
              const Spacer(),
              if (bytes != null)
                Text(
                  'READY',
                  style: AppType.data.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.unit),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.unit * 1.5),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: bytes == null
                  ? Container(
                      color: AppColors.inkDeep.withValues(alpha: 0.5),
                      child: const Center(
                        child: Icon(
                          Icons.person_outline,
                          size: 40,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : Image.memory(bytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Wrap(
            spacing: AppSpacing.unit,
            children: [
              AtelierButton(
                label: 'Camera',
                variant: AtelierButtonVariant.secondary,
                fullWidth: false,
                onPressed: () => onPick(ImageSource.camera),
              ),
              AtelierButton(
                label: 'Choose file',
                variant: AtelierButtonVariant.ghost,
                fullWidth: false,
                onPressed: () => onPick(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The labeled try-on result: method + confidence permanently visible
/// (PRODUCT_SPEC §7), Before/After slider, zoom. Public so tests and future
/// previews can judge it with real-shaped payloads.
class TryOnResultView extends StatelessWidget {
  const TryOnResultView({super.key, required this.result, required this.person});

  final TryOnSuccess result;
  final Uint8List person;

  @override
  Widget build(BuildContext context) {
    final lowConfidence = result.flags.contains('LOW_CONFIDENCE');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // §7: method + confidence always visible, in the Data typeface.
        Row(
          children: [
            Expanded(
              child: Text(
                '${result.render.method} · ${result.render.provider}',
                style: AppType.data.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              'CONFIDENCE ${(result.confidence * 100).round()}%',
              style: AppType.data.copyWith(
                fontSize: 12,
                color: lowConfidence ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (lowConfidence) ...[
          const SizedBox(height: AppSpacing.half),
          Text(
            'LOW CONFIDENCE — the render drifts from the source garment. '
            'Treat it as a sketch, not a fit.',
            style: AppType.data.copyWith(fontSize: 11, color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.unit * 2),
        _CompareSlider(before: person, after: result.render.imageBytes),
        const SizedBox(height: AppSpacing.unit),
        Text(
          'Drag the handle to compare. Pinch to zoom.',
          style: AppType.interface.copyWith(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Before/After comparison — one of the two jank-critical surfaces
/// (DESIGN_SYSTEM §3), so it is a plain ClipRect over two images.
class _CompareSlider extends StatefulWidget {
  const _CompareSlider({required this.before, required this.after});

  final Uint8List before;
  final Uint8List after;

  @override
  State<_CompareSlider> createState() => _CompareSliderState();
}

class _CompareSliderState extends State<_CompareSlider> {
  double _t = 0.5;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return InteractiveViewer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(widget.after, fit: BoxFit.cover),
                  ClipRect(
                    clipper: _LeftClip(fraction: _t),
                    child: Image.memory(widget.before, fit: BoxFit.cover),
                  ),
                  Positioned(
                    left: width * _t - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: AppColors.textPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  // The drag strip sits above the viewer so the slider and
                  // the pinch-to-zoom never fight over the same gesture.
                  Positioned(
                    left: width * _t - AppSpacing.minTapTarget / 2,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (d) {
                        setState(() {
                          _t = (_t + d.delta.dx / width).clamp(0.0, 1.0);
                        });
                      },
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.surfacePrimary
                                .withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: const Icon(
                            Icons.unfold_more,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 8,
                    top: 8,
                    child: _Tag('BEFORE'),
                  ),
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: _Tag('AFTER'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LeftClip extends CustomClipper<Rect> {
  const _LeftClip({required this.fraction});

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftClip oldClipper) => oldClipper.fraction != fraction;
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppType.data.copyWith(
        fontSize: 10,
        letterSpacing: 1.2,
        color: AppColors.textPrimary,
        shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.code, required this.message});

  final String code;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.unit * 2.5),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: AppType.data.copyWith(fontSize: 12, color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.half),
          Text(
            message,
            style: AppType.interface.copyWith(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.4),
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
        ),
        child: Center(
          child: Text(
            'The provider is rendering…',
            style: AppType.interface.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
