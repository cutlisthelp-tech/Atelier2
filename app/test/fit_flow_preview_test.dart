/// The fit-flow preview is a developer design exploration: it must carry its
/// SAMPLE DATA label, run gathering on a deterministic question list (no LLM
/// provider), and render the honest states — a skipped measurement becomes
/// "not scored", a missing chart is NO_SIZE_CHART, and the trend slot is
/// inactive by default. Unlabeled sample content would violate the
/// no-fake-data rule.
library;

import 'package:atelier/ui/screens/fit_flow_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 60,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the labeled flow with honest states', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: FitFlowPreviewScreen()));
    await tester.pump();

    expect(find.textContaining('SAMPLE DATA'), findsOneWidget);
    // Gathering is provider-agnostic: a deterministic list, no LLM call.
    expect(
      find.textContaining('DETERMINISTIC LIST'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text("I don't have this number"), findsOneWidget);

    // Both size-chart states are on display.
    await _scrollTo(tester, find.text('Use this chart'));
    expect(find.text('Use this chart'), findsOneWidget);
    await _scrollTo(tester, find.text('No size chart on this page.'));
    expect(find.text('No size chart on this page.'), findsOneWidget);

    // The real result card renders, and the trend slot defaults to its
    // honest inactive state.
    await _scrollTo(tester, find.text('Personal Match'));
    expect(find.text('Personal Match'), findsOneWidget);
    await _scrollTo(tester, find.textContaining('Trend context'));
    expect(find.textContaining('Trend context'), findsWidgets);
  });

  testWidgets('skipping every question yields an honest not-scored summary',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: FitFlowPreviewScreen()));
    await tester.pump();

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text("I don't have this number"));
      await tester.pump();
    }

    expect(find.textContaining('4 skipped'), findsOneWidget);
    // Every skipped region is listed, never guessed or scored.
    expect(find.textContaining('not provided'), findsNWidgets(4));

    await tester.tap(find.text('Start over'));
    await tester.pump();
    expect(find.text('Continue'), findsOneWidget);
  });
}
