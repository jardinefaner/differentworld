// The loop a substitute needs, on the SCREEN: brief → play → an ending you
// can see → Play again. The reducer tests prove a board can end; these prove
// a person can see the ending and act on it. Nineteen classics had the first
// and not the second — the scaffold returned early for any game that draws
// its own board, so "Play again", "Done" and the closing line never rendered.

import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/connect_four_game.dart';
import 'package:differentworld/features/games/round_wrap.dart';
import 'package:differentworld/features/live_session/shape_stage_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_briefing.dart';

void main() {
  Future<void> pumpGame(WidgetTester tester, Widget game) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: game)),
    );
    await tester.pump();
    await skipTheBriefing(tester);
  }

  /// The board's cells, in index order, as the renderer lays them out.
  List<Element> cells(WidgetTester tester) {
    final grid = find.byType(ShapeStageView);
    expect(grid, findsOneWidget, reason: 'the board is on screen');
    return find
        .descendant(of: grid, matching: find.byType(GestureDetector))
        .evaluate()
        .toList();
  }

  testWidgets('a won Connect Four shows Play again, and it deals afresh', (
    tester,
  ) async {
    await pumpGame(tester, const GameRunner(def: ConnectFourGame()));
    expect(find.byType(RoundWrap), findsNothing, reason: 'mid-round');

    // Red in column 0, yellow in column 1, alternating — four reds vertical.
    for (var move = 0; move < 7; move++) {
      final col = move.isEven ? 0 : 1;
      await tester.tap(find.byWidget(cells(tester)[col].widget));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.byType(RoundWrap), findsOneWidget, reason: 'the ending shows');
    expect(find.textContaining('wins'), findsWidgets);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('round-wrap-again')));
    await tester.pumpAndSettle();
    expect(find.byType(RoundWrap), findsNothing, reason: 'a new round');
    expect(
      find.text('Start'),
      findsNothing,
      reason: 'play again does not re-brief — the room just played',
    );
    expect(find.byType(ShapeStageView), findsOneWidget, reason: 'dealt');
  });

  testWidgets('the rules can be re-opened from the wrap beat', (tester) async {
    // The top pill's "How to play" lives in the app chrome, which this
    // harness does not mount; the wrap beat carries the same verb.
    await pumpGame(tester, const GameRunner(def: ConnectFourGame()));
    for (var move = 0; move < 7; move++) {
      final col = move.isEven ? 0 : 1;
      await tester.tap(find.byWidget(cells(tester)[col].widget));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('round-wrap-rules')));
    await tester.pumpAndSettle();
    expect(find.text('We are playing Connect Four'), findsOneWidget);
    await skipTheBriefing(tester);
    expect(find.byType(ShapeStageView), findsOneWidget);
    expect(
      find.byType(RoundWrap),
      findsOneWidget,
      reason: 'the round underneath was still over',
    );
  });

  testWidgets('a face-up square takes a tap (Bingo marks it)', (tester) async {
    // The renderer used to accept taps only on face-DOWN cells, which made
    // every board that starts face-up — Bingo, Boggle, Word Search, Guess
    // Who, Four Corners, Scavenger, Simon, Snakes & Ladders, Lights Out —
    // something the room could look at and not play.
    await pumpGame(tester, const GameRunner(def: BingoGame()));
    final before = find.textContaining(' of 16');
    expect(before, findsNothing, reason: 'nothing marked yet');
    await tester.tap(find.byWidget(cells(tester)[5].widget));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 16'), findsOneWidget);
  });

  testWidgets('Charades on one device shows the actor the word', (
    tester,
  ) async {
    await pumpGame(tester, const GameRunner(def: CharadesGame()));
    // The secret stage carries the "room can't see this" caption; the room
    // stage never does. One phone in a host's hand IS the actor's card.
    expect(find.textContaining("the room can't see this"), findsOneWidget);
    expect(find.text('Got it!'), findsOneWidget);
  });
}
