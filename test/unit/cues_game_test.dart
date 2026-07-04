// CuesGame — attention signals presentable (docs/VISION.md #18). The `pick`
// intent jumps to a cue; static cue list, so only the index rides the wire.

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/cues_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const def = CuesGame();

  group('CuesGame.reduce', () {
    test('pick jumps to the chosen cue', () {
      expect(def.reduce({'i': 0}, GameIntent.pick, const {'cue': 4})['i'], 4);
    });

    test('pick ignores out-of-range', () {
      expect(def.reduce({'i': 3}, GameIntent.pick, const {'cue': 99})['i'], 3);
    });

    test('next advances and wraps; reset returns to 0', () {
      expect(def.reduce({'i': 0}, GameIntent.next, const {})['i'], 1);
      expect(def.reduce({'i': 7}, GameIntent.next, const {})['i'], 0);
      expect(def.reduce({'i': 5}, GameIntent.reset, const {})['i'], 0);
    });
  });

  testWidgets('tapping a cue button shows it big on the stage', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: GameRunner(def: CuesGame())),
      ),
    );
    await tester.pump();

    // Opens on the first cue; "Clean up" (the stage label) isn't showing yet.
    expect(find.text('Clean up'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, '🧹 Clean up'));
    await tester.pumpAndSettle();
    expect(find.text('Clean up'), findsOneWidget); // now on the stage
  });
}
