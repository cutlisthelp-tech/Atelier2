import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class TryOnScreen extends StatelessWidget {
  const TryOnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Try On isn\'t connected yet.',
      message:
          'This screen renders a garment on your real photo with a dedicated '
          'try-on model, always labeled with its method and confidence. No '
          'model is linked yet, so there is nothing to render.',
    );
  }
}
