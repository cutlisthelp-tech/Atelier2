import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Your best look appears here.',
      message:
          'Atelier hasn\'t met you yet. Start with a body scan in Profile — '
          'once it knows your proportions and colors, this is where your top '
          'outfit for the day lands, scored for your occasion and weather.',
    );
  }
}
