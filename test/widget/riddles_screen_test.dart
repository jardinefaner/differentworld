// Widget test for Riddle Me This — now on the unified Game framework
// (docs/GAMES.md Wave 1b): GameRunner + RiddlesGame. Host-present, NO typing,
// NO grading — the room guesses aloud, the teacher Reveals then advances.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/riddles_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness() => const ProviderScope(
    child: MaterialApp(home: GameRunner(def: RiddlesGame())),
  );

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
    await tester.pumpAndSettle();
    expect(find.text('?'), findsNothing); // answer is now showing

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
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
