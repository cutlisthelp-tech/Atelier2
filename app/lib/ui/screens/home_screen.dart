import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Your best look appears here.',
      message:
          'Atelier hasn\'t met you yet. Once body scanning ships, this is '
          'where your top outfit for the day lands — scored for your '
          'proportions, your colors, your occasion, your weather.',
    );
  }
}
