// Widget test for the Math game screen (docs/ACTIVITY_ROADMAP.md Wave 2).
// Host-present: NO typing, NO grading — the room answers aloud, the teacher
// taps Reveal (glows the answer) then Next. No score.

import 'package:differentworld/features/activity_runtime/math_game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const MathGameScreen())],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens on Q1 with a Reveal — no typing, no score', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(TextField), findsNothing); // no typing
    expect(find.text('1 / 8'), findsOneWidget); // no "⭐ score"
    expect(find.widgetWithText(FilledButton, 'Reveal'), findsOneWidget);
  });

  testWidgets('Reveal then Next advances to the next question', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Reveal'));
    await tester.pump();
    // Reveal swaps to Next (the answer glows; no ✓/✗ grading text).
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
    expect(find.text('2 / 8'), findsOneWidget);
  });
}
