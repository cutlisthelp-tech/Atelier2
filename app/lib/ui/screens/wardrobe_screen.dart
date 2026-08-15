import 'package:flutter/material.dart';

import '../../services/backend_client.dart';
import '../widgets/empty_state.dart';
import 'garment_scan_screen.dart';

/// Phase 2 entry point: photograph one garment and read its real analysis.
/// Nothing is stored on the device yet — wardrobe persistence arrives with
/// the Phase 7 Wardrobe module.
class WardrobeScreen extends StatelessWidget {
  const WardrobeScreen({super.key, required this.backendClient});

  final BackendClient backendClient;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'Your wardrobe is empty.',
      message:
          'Photograph what you own and Atelier reads each piece — category, '
          'colors, pattern, fit, material. Nothing is stored on this device '
          'yet; saved wardrobe items arrive later.',
      actionLabel: 'Photograph a garment',
      onAction: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GarmentScanScreen(client: backendClient),
        ),
      ),
    );
  }
}
