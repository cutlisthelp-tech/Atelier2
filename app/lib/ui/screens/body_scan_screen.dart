import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../models/analysis.dart';
import '../../services/backend_client.dart';
import '../../services/local_store.dart';
import '../../theme/tokens.dart';
import 'scan_result_screen.dart';

/// Camera capture → backend analysis → honest result. The analyzing state is
/// deliberately plain: no fake progress, no invented ETA. On success the raw
/// payloads are persisted so HOME can send them back for scoring (Phase 3).
class BodyScanScreen extends StatefulWidget {
  const BodyScanScreen({
    super.key,
    required this.client,
    required this.heightCm,
    this.camerasFinder = availableCameras,
    this.bodyStore,
    this.appearanceStore,
  });

  final BackendClient client;
  final double heightCm;
  final Future<List<CameraDescription>> Function() camerasFinder;
  final ScanRecordStore? bodyStore;
  final ScanRecordStore? appearanceStore;

  @override
  State<BodyScanScreen> createState() => _BodyScanScreenState();
}

class _BodyScanScreenState extends State<BodyScanScreen> {
  CameraController? _controller;
  String? _cameraError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await widget.camerasFinder();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No camera was found on this device.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(camera, ResolutionPreset.high);
      await controller.initialize();
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError =
            'The camera could not be started. Check camera permission and try again.');
      }
    }
  }

  Future<void> _captureAndAnalyze() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();
      final bodyOutcome = await widget.client.analyzeBody(bytes, widget.heightCm);
      AppearanceScanSuccess? appearance;
      if (bodyOutcome is BodyScanSuccess) {
        await widget.bodyStore?.save(bodyOutcome.payload);
        final colorOutcome = await widget.client.analyzeAppearance(bytes);
        if (colorOutcome is AppearanceScanSuccess) {
          appearance = colorOutcome;
          await widget.appearanceStore?.save(appearance.payload);
        }
        // A full-body capture often has no usable face — that is not an error.
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            outcome: bodyOutcome,
            capture: bytes,
            appearance: appearance,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ScanResultScreen(
              outcome: ScanFailure(
                code: 'NETWORK_ERROR',
                message: 'The capture could not be completed. Try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Body scan', style: AppType.interface)),
      body: SafeArea(
        child: _cameraError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.unit * 3),
                  child: Text(
                    _cameraError!,
                    textAlign: TextAlign.center,
                    style: AppType.interface.copyWith(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: _controller == null || !_controller!.value.isInitialized
                        ? const Center(
                            child: Text(
                              'Starting camera…',
                              style: AppType.interface,
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_controller!),
                              Positioned(
                                bottom: AppSpacing.unit * 10,
                                left: 0,
                                right: 0,
                                child: Text(
                                  'Stand back — full body in frame, facing the camera.',
                                  textAlign: TextAlign.center,
                                  style: AppType.interface.copyWith(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    shadows: const [
                                      Shadow(blurRadius: 8, color: Colors.black54),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.unit * 2),
                    child: SizedBox(
                      height: AppSpacing.minTapTarget,
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.surfacePrimary,
                        ),
                        onPressed: _busy || _controller == null
                            ? null
                            : _captureAndAnalyze,
                        child: Text(
                          _busy ? 'Analyzing — hold still…' : 'Capture',
                          style: AppType.interface.copyWith(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
