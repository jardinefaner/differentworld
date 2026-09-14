// Play again on a DECK-seeded board deals a real second board.
//
// The reducer's reset turns every square face-down — right for Minesweeper,
// wrong for Bingo, which is played face-up. Before the wrapper passed a
// reseed builder, round two of a deck-seeded Bingo was sixteen dark tiles
// with the pictures gone. Nobody saw it because round one had no Play again.

import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/games/classic_boards_screen.dart';
import 'package:differentworld/features/games/round_wrap.dart';
import 'package:differentworld/features/live_session/shape_stage_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_briefing.dart';

void main() {
  testWidgets('a seeded Bingo deals face-up again after Play again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: BingoScreen(live: false)),
      ),
    );
    // The deck manifest loads from assets asynchronously.
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await skipTheBriefing(tester);
    await tester.pumpAndSettle();

    final grid = find.byType(ShapeStageView);
    expect(grid, findsOneWidget);
    final before = find.descendant(of: grid, matching: find.byType(CardTile));
    expect(before, findsNWidgets(16), reason: 'sixteen pictures, face up');

    // Cross off the top row — a line — to end the round.
    final cells = find
        .descendant(of: grid, matching: find.byType(GestureDetector))
        .evaluate()
        .toList();
    for (final i in [0, 1, 2, 3]) {
      await tester.tap(find.byWidget(cells[i].widget));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.byType(RoundWrap), findsOneWidget, reason: 'Bingo!');

    await tester.tap(find.byKey(const ValueKey('round-wrap-again')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(RoundWrap), findsNothing);
    final after = find.descendant(
      of: find.byType(ShapeStageView),
      matching: find.byType(CardTile),
    );
    expect(
      after,
      findsNWidgets(16),
      reason: 'round two shows its pictures — not sixteen face-down tiles',
    );
  });
}
