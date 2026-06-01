// Widget test for Riddles (more games wave). Host-present: NO typing, NO
// grading — the room guesses aloud, the teacher Reveals then advances.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/riddles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const RiddlesScreen())],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  testWidgets('opens on the first riddle with a Reveal — no typing', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(TextField), findsNothing); // no typing
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reveal'), findsOneWidget);
    expect(find.text('?'), findsOneWidget); // answer hidden until reveal
  });

  testWidgets('Reveal shows the answer, then Next advances', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Reveal'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
    expect(find.text('?'), findsNothing); // answer is now showing

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
    expect(find.text('2 / 10'), findsOneWidget);
  });

  test('riddle seed is answer-first — every item has a prompt + answer', () {
    final bank = LocalContentBank.seeded();
    final riddles = bank.take(ContentKind.riddle, 100);
    expect(riddles.length, greaterThanOrEqualTo(12));
    for (final r in riddles) {
      expect((r.payload['prompt']! as String).trim(), isNotEmpty);
      expect((r.payload['answer']! as String).trim(), isNotEmpty);
    }
  });
}
