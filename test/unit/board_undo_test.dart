// A mis-tap on a board used to be permanent.
//
// `GameIntent.back` fell through to `default: return state`, so on the
// classics a wrong square cost a turn (Battleship), marked a row that could
// not be unmarked (Bingo), or ended the round outright (Minesweeper). The
// control bar has always DRAWN a back arrow for any game that offers the
// intent — the boards simply never offered it, so the button was absent from
// nineteen games rather than disabled on them.
//
// A teacher runs these one-handed, in a loud room, often as a substitute. A
// wrong tap is not an edge case.

import 'dart:convert';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:flutter_test/flutter_test.dart';

final _bank = LocalContentBank.seededWith(curatedSeeds);

/// Tap the first cell the game will actually accept, and hand back both
/// states. Null when the game declines every square (nothing to undo).
({Map<String, dynamic> before, Map<String, dynamic> after})? _aMove(
  GridGame g,
) {
  final start = g.initialState(_bank);
  for (var i = 0; i < GridBoard.fromWire(start).cells.length; i++) {
    final after = g.reduce(start, GameIntent.pick, {'cell': i});
    if (after.toString() != start.toString()) {
      return (before: start, after: after);
    }
  }
  return null;
}

void main() {
  final boards = liveGames.whereType<GridGame>().toList();

  test('every board that takes a tap can take it back', () {
    final permanent = <String>[];
    var checked = 0;
    for (final g in boards) {
      final move = _aMove(g);
      if (move == null) continue;
      checked++;
      final undone = g.reduce(move.after, GameIntent.back, const {});
      // The snapshot itself is not part of "the same board" — compare the
      // board, not the bookkeeping.
      final a = Map<String, dynamic>.from(undone)..remove('u');
      final b = Map<String, dynamic>.from(move.before)..remove('u');
      if (jsonEncode(a) != jsonEncode(b)) permanent.add(g.id);
    }
    expect(checked, greaterThan(10), reason: 'the probe stopped finding moves');
    expect(
      permanent,
      isEmpty,
      reason: 'a wrong tap on these cannot be taken back: $permanent',
    );
  });

  test('the arrow appears only once there IS something to take back', () {
    for (final g in boards) {
      final move = _aMove(g);
      if (move == null) continue;
      expect(
        g.activeIntents(g.decode(move.before)),
        isNot(contains(GameIntent.back)),
        reason: '${g.id} offers Back on a board nobody has touched',
      );
      expect(
        g.activeIntents(g.decode(move.after)),
        contains(GameIntent.back),
        reason: '${g.id} took a move and will not give it back',
      );
    }
  });

  test('one step, not a stack', () {
    // Undoing twice must not walk further back than the one move a person
    // means by "take that back" — and must not crash looking for a second.
    final g = boards.firstWhere((g) => _aMove(g) != null);
    final move = _aMove(g)!;
    final once = g.reduce(move.after, GameIntent.back, const {});
    final twice = g.reduce(once, GameIntent.back, const {});
    expect(
      jsonEncode(twice..remove('u')),
      jsonEncode(Map<String, dynamic>.from(once)..remove('u')),
      reason: 'a second Back moved the board again',
    );
  });

  test('Play again does not leave the old round reachable', () {
    // Carrying the snapshot across a reset would let Back walk a fresh board
    // into the last round's cells — a whole different game appearing.
    for (final g in boards) {
      final move = _aMove(g);
      if (move == null) continue;
      final fresh = g.reduce(move.after, GameIntent.reset, const {});
      expect(
        g.decode(fresh).canUndo,
        isFalse,
        reason: '${g.id} can undo its way back into the previous round',
      );
    }
  });

  test('a tick is not a move — the clock does not fill the undo slot', () {
    // Otherwise Whack-a-Mole's Back would undo the mole moving rather than
    // the square the teacher tapped by mistake, every second.
    for (final g in boards.where((g) => g.ticks)) {
      final start = g.initialState(_bank);
      final ticked = g.reduce(start, GameIntent.tick, const {});
      expect(
        g.decode(ticked).canUndo,
        isFalse,
        reason: '${g.id} treats its own clock as something to take back',
      );
    }
  });
}
