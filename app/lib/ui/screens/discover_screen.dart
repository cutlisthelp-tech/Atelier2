import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'No catalog connected.',
      message:
          'Atelier only shows real products from licensed catalogs. None is '
          'linked yet, so there is nothing to discover — and nothing fake '
          'to fill the gap.',
    );
  }
}
