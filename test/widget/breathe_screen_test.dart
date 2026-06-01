// Widget test for Mindful Minute (more games wave 2). A calm breathing
// break — starts paused, tap begins; no typing, no score.

import 'package:differentworld/features/activity_runtime/breathe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const BreatheScreen())],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('starts paused with no typing, tap begins then pauses', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Tap to begin'), findsOneWidget);

    // Tap anywhere starts the breathing cycle.
    await tester.tap(find.byType(BreatheScreen));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tap to begin'), findsNothing);
    expect(find.textContaining('Breathe'), findsWidgets);

    // Pause again so no ticker is pending at teardown.
    await tester.tap(find.byType(BreatheScreen));
    await tester.pump();
  });
}
