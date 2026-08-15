import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../models/analysis.dart';
import '../../services/backend_client.dart';
import '../../services/local_store.dart';
import '../../theme/tokens.dart';
import 'scan_result_screen.dart';

/// Camera capture → backend garment analysis → honest result. Garments are
/// not biometric data, so no consent gate precedes this flow. A successful
/// analysis is added to the local wardrobe (analysis JSON only).
class GarmentScanScreen extends StatefulWidget {
  const GarmentScanScreen({
    super.key,
    required this.client,
    this.camerasFinder = availableCameras,
    this.wardrobeStore,
  });

  final BackendClient client;
  final Future<List<CameraDescription>> Function() camerasFinder;
  final WardrobeStore? wardrobeStore;

  @override
  State<GarmentScanScreen> createState() => _GarmentScanScreenState();
}

class _GarmentScanScreenState extends State<GarmentScanScreen> {
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
      final outcome = await widget.client.analyzeGarment(bytes);
      if (outcome is GarmentScanSuccess &&
          outcome.garment.category.value != null) {
        await widget.wardrobeStore?.add(outcome.payload);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(outcome: outcome, capture: bytes),
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
      appBar: AppBar(title: Text('Garment scan', style: AppType.interface)),
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
                                  'One garment — worn, hung, or laid flat, in good light.',
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
                          _busy ? 'Analyzing…' : 'Capture',
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
