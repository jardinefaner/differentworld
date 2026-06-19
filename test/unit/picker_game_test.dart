// PickerGame — Spotlight, a data-driven presentable (docs/VISION.md #18).
// Names are seeded (here directly; in the app from the roster). The random
// pick is passed in `args`, so the reducer is pure + testable.

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/picker_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const def = PickerGame();

  Map<String, dynamic> st({int i = 0, bool spun = false}) => {
    'names': const ['Ana', 'Bex', 'Cy', 'Dee'],
    'i': i,
    'spun': spun,
  };

  group('PickerGame.reduce', () {
    test('next with a pick lands on that name and marks spun', () {
      final r = def.reduce(st(), GameIntent.next, const {'pick': 2});
      expect(r['i'], 2);
      expect(r['spun'], isTrue);
      expect(def.decode(r).current, 'Cy');
    });

    test('next without a pick advances; reset clears spun', () {
      expect(def.reduce(st(), GameIntent.next, const {})['i'], 1);
      final r = def.reduce(st(i: 3, spun: true), GameIntent.reset, const {});
      expect(r['spun'], isFalse);
      expect(r['i'], 0);
    });

    test('next on an empty roster is a no-op', () {
      final empty = {'names': const <String>[], 'i': 0, 'spun': false};
      expect(def.reduce(empty, GameIntent.next, const {})['spun'], isFalse);
    });
  });

  testWidgets('Spin lands on someone (full loop, seeded roster)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GameRunner(
            def: PickerGame(),
            seed: {
              'names': ['Ana', 'Bex', 'Cy'],
              'i': 0,
              'spun': false,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tap Spin'), findsOneWidget); // prompt, pre-spin
    await tester.tap(find.widgetWithText(FilledButton, 'Spin'));
    await tester.pumpAndSettle();

    // GameStage.eyebrow renders tracked-caps (the immersive game-stage style).
    expect(find.text("YOU'RE UP!"), findsOneWidget); // landed
    expect(find.widgetWithText(FilledButton, 'Spin again'), findsOneWidget);
  });
}
