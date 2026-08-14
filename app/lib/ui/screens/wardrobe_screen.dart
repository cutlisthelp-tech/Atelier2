import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class WardrobeScreen extends StatelessWidget {
  const WardrobeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Your wardrobe is empty.',
      message:
          'Photograph what you own and Atelier learns each piece — category, '
          'color, fit type. Garment analysis arrives in a later phase, so '
          'nothing is stored yet.',
    );
  }
}
