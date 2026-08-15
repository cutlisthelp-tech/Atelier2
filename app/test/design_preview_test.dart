/// The design preview is a developer screen: it must render the real result
/// card and must carry its SAMPLE DATA label — unlabeled sample data would
/// violate the no-fake-data rule.
library;

import 'package:atelier/ui/screens/design_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the populated card with an explicit sample label',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        const MaterialApp(home: DesignPreviewScreen()));
    await tester.pump();

    expect(find.textContaining('SAMPLE DATA'), findsOneWidget);
    expect(find.text('Personal Match'), findsOneWidget);
    expect(find.text('71'), findsOneWidget);
    expect(find.text('sweater'), findsOneWidget);
    expect(find.text('jeans'), findsOneWidget);
    expect(find.text('sneakers'), findsOneWidget);
    expect(find.text('Why it works'), findsOneWidget);
    expect(find.text('safer'), findsOneWidget); // honest alternatives strip
  });
}
