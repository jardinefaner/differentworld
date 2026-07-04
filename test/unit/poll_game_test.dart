// PollGame — the first NON-game presentable (docs/VISION.md #18). Proves the
// present/control engine drives a real group decision: per-option tally via
// buildControls, reveal the winner. Reducer + a tap-to-tally widget test that
// exercises the full GameRunner → controller → reducer loop.

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/poll_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const def = PollGame();

  Map<String, dynamic> st({List<int>? counts, bool r = false}) => {
    'q': 'What should we do next?',
    'options': const ['Outside', 'Art', 'Building', 'Reading'],
    'counts': counts ?? const [0, 0, 0, 0],
    'r': r,
  };

  group('PollGame.reduce', () {
    test('tally adds a vote to the chosen option only', () {
      final r = def.reduce(st(), GameIntent.tally, const {'choice': 1});
      expect(r['counts'], [0, 1, 0, 0]);
    });

    test('tally ignores an out-of-range / missing choice', () {
      expect(
        def.reduce(st(), GameIntent.tally, const {'choice': 9})['counts'],
        [0, 0, 0, 0],
      );
      expect(def.reduce(st(), GameIntent.tally, const {})['counts'], [
        0,
        0,
        0,
        0,
      ]);
    });

    test('reveal toggles; reset zeroes the counts and hides', () {
      expect(def.reduce(st(), GameIntent.reveal, const {})['r'], isTrue);
      final r = def.reduce(
        st(counts: [3, 1, 0, 2], r: true),
        GameIntent.reset,
        const {},
      );
      expect(r['counts'], [0, 0, 0, 0]);
      expect(r['r'], isFalse);
    });

    test('winnerIndex picks the leading option', () {
      expect(def.decode(st(counts: [1, 4, 2, 0])).winnerIndex, 1);
      expect(def.decode(st(counts: [0, 0, 5, 0])).totalVotes, 5);
    });
  });

  testWidgets('tapping an option button records a vote (full loop)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: GameRunner(def: PollGame())),
      ),
    );
    await tester.pump();

    expect(find.text('What should we do next?'), findsOneWidget);
    // The control button starts at "Outside  0"; tapping it tallies a vote.
    final button = find.widgetWithText(FilledButton, 'Outside  0');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Outside  1'), findsOneWidget);
  });
}
