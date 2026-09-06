// The four classics, tested where they can actually be WRONG.
//
// Their rendering, wire format and reducer all come from GridGame, which is
// covered elsewhere — so these pin the RULES: what a tap does, when somebody
// has won, and the refusals that stop a stray tap costing a turn.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/battleship_game.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/connect_four_game.dart';
import 'package:differentworld/features/games/games/guess_who_game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GridBoard board(
  GameDefinition<GridBoard> def,
  Map<String, dynamic> wire,
) => def.decode(wire);

Map<String, dynamic> tap(
  GameDefinition<GridBoard> def,
  Map<String, dynamic> wire,
  int cell,
) => def.reduce(wire, GameIntent.pick, {'cell': cell});

Map<String, dynamic> filled(int cols, int rows, CellState s, {String? face}) =>
    GridBoard(
      cols: cols,
      rows: rows,
      cells: List.generate(cols * rows, (_) => BoardCell(face: face, state: s)),
    ).toWire();

void main() {
  group('Bingo', () {
    const g = BingoGame();

    test('a tap crosses off, and a second tap un-crosses', () {
      var w = filled(4, 4, CellState.shown, face: '🍎');
      w = tap(g, w, 5);
      expect(board(g, w).cells[5].state, CellState.done);
      // Somebody always mishears a call.
      w = tap(g, w, 5);
      expect(board(g, w).cells[5].state, CellState.shown);
    });

    test('a full row is a win; four scattered squares are not', () {
      var w = filled(4, 4, CellState.shown, face: '🍎');
      for (final i in [0, 1, 2, 3]) {
        w = tap(g, w, i);
      }
      expect(g.titleFor(board(g, w)), 'Bingo!');

      var scattered = filled(4, 4, CellState.shown, face: '🍎');
      for (final i in [0, 5, 11, 14]) {
        scattered = tap(g, scattered, i);
      }
      expect(g.titleFor(board(g, scattered)), isNot('Bingo!'));
    });

    test('a diagonal counts', () {
      var w = filled(4, 4, CellState.shown, face: '🍎');
      for (final i in [0, 5, 10, 15]) {
        w = tap(g, w, i);
      }
      expect(g.titleFor(board(g, w)), 'Bingo!');
    });
  });

  group('Battleship', () {
    const g = BattleshipGame();

    test('firing twice on one square is refused', () {
      final start = g.initialState(const _NoContent());
      final once = tap(g, start, 7);
      final twice = tap(g, once, 7);
      // Not "harmless" — identical. A repeat tap must not read as a new shot.
      expect(twice, once);
    });

    test('the label is what a room says out loud', () {
      expect(BattleshipGame.label(0, 5), 'A1');
      expect(BattleshipGame.label(7, 5), 'C2');
      expect(BattleshipGame.label(24, 5), 'E5');
    });

    test('every square is a hit or a miss, and five are hits', () {
      final b = board(g, g.initialState(const _NoContent()));
      expect(b.cells.length, 25);
      expect(b.cells.where((c) => c.face == '💥').length, 5);
      expect(b.cells.every((c) => c.face != null), isTrue);
    });
  });

  group('Guess Who', () {
    const g = GuessWhoGame();

    test('ruling out is reversible — a room changes its mind', () {
      var w = filled(4, 3, CellState.shown, face: '🙂');
      w = tap(g, w, 3);
      expect(board(g, w).cells[3].state, CellState.done);
      w = tap(g, w, 3);
      expect(board(g, w).cells[3].state, CellState.shown);
    });

    test('one left is the answer', () {
      var w = filled(4, 3, CellState.shown, face: '🙂');
      for (var i = 1; i < 12; i++) {
        w = tap(g, w, i);
      }
      expect(g.titleFor(board(g, w)), 'That is who!');
      expect(g.noteFor(board(g, w)), '1 left');
    });
  });

  group('Connect Four', () {
    const g = ConnectFourGame();
    final empty = g.initialState(const _NoContent());

    test('a counter falls to the bottom of its column', () {
      // Tap the TOP of column 3; it must land on the bottom row.
      final w = tap(g, empty, 3);
      final b = board(g, w);
      expect(b.cells[5 * 7 + 3].face, isNotNull);
      expect(b.cells[3].face, isNull);
    });

    test('play alternates, and stacks', () {
      var w = tap(g, empty, 3);
      w = tap(g, w, 3);
      final b = board(g, w);
      expect(b.cells[5 * 7 + 3].face, '🔴');
      expect(b.cells[4 * 7 + 3].face, '🟡');
    });

    test('a full column refuses, and does not cost a turn', () {
      var w = empty;
      for (var i = 0; i < 6; i++) {
        w = tap(g, w, 0);
      }
      final before = board(g, w).turn;
      final after = tap(g, w, 0);
      expect(after, w);
      expect(board(g, after).turn, before);
    });

    test('four in a row wins; three does not', () {
      // Red takes columns 0-3 along the bottom; yellow answers in column 6.
      var w = empty;
      for (final c in [0, 6, 1, 6, 2, 6]) {
        w = tap(g, w, c);
      }
      expect(g.titleFor(board(g, w)), isNull, reason: 'three is not four');
      w = tap(g, w, 3);
      expect(g.titleFor(board(g, w)), '🔴 wins!');
    });

    test('a vertical line wins too', () {
      var w = empty;
      for (final c in [2, 5, 2, 5, 2, 5, 2]) {
        w = tap(g, w, c);
      }
      expect(g.titleFor(board(g, w)), '🔴 wins!');
    });
  });

  testWidgets('an unloaded deck shows the empty state, not a blank board', (
    tester,
  ) async {
    // A board with no squares is a deck that has not loaded. Putting an empty
    // grid on the room's TV would say nothing about why.
    const g = GuessWhoGame();
    final b = board(g, g.initialState(const _NoContent()));
    expect(b.cells, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) => g.buildStage(ctx, b)),
        ),
      ),
    );
    expect(
      find.byType(DeckEmptyStage),
      findsOneWidget,
      reason: 'a blank stage explains nothing to the room',
    );
  });

  test('every classic describes itself as a grid', () {
    // The reason they cast to a screen that has never heard of them.
    for (final g in <GameDefinition<GridBoard>>[
      const BingoGame(),
      const BattleshipGame(),
      const GuessWhoGame(),
      const ConnectFourGame(),
    ]) {
      final shape = g.asShape(board(g, g.initialState(const _NoContent())));
      expect(shape?.kind, ShapeKind.grid, reason: '${g.id} must be a grid');
      // Battleship and Connect Four are their own board, so they deal a full
      // one from nothing. Bingo pads a short deck. Guess Who genuinely has no
      // faces without one — GridGame shows the shared empty state rather than
      // a blank stage, which is asserted below.
      if (g.id != 'guess-who') {
        expect(
          shape!.cells,
          isNotEmpty,
          reason: '${g.id} dealt an empty board',
        );
      }
    }
  });
}

/// Battleship and Connect Four are their own board — they ask the content
/// source for nothing, and this proves it rather than assuming it.
class _NoContent implements ContentSource {
  const _NoContent();

  @override
  List<ContentItem> take(String kind, int n) => const [];

  @override
  int remaining(String kind) => 0;

  @override
  ContentItem? next(String kind) => null;
}
