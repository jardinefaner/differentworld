import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Snakes & Ladders.** Roll, move, and hope.
///
/// I listed this as needing a different shape because a token moves along a
/// path. It does not: the path IS a grid, and the token is a face on one
/// square. The board was a grid the whole time.
class SnakesLaddersGame extends GridGame {
  const SnakesLaddersGame();

  static const _token = '🔴';
  static const _snake = '🐍';
  static const _ladder = '🪜';

  /// from → to. Short hops, so a bad roll is a setback rather than the end of
  /// somebody's afternoon.
  static const _jumps = <int, int>{
    5: 14,
    9: 21,
    17: 28,
    20: 8,
    26: 12,
    31: 6,
    33: 19,
  };

  @override
  String get id => 'snakes-ladders';

  @override
  String get title => 'Snakes & Ladders';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.sage);

  @override
  int get cols => 6;

  @override
  int get rows => 6;

  @override
  List<BoardCell> deal(ContentSource content) => [
    for (var i = 0; i < 36; i++)
      BoardCell(
        label: '${i + 1}',
        face: i == 0
            ? _token
            : (_jumps[i] == null ? null : (_jumps[i]! > i ? _ladder : _snake)),
        state: CellState.shown,
      ),
  ];

  static int _at(GridBoard b) =>
      b.cells.indexWhere((c) => c.face == _token).clamp(0, b.cells.length - 1);

  /// Any tap is a roll — one to six, then the snake or the ladder if you land
  /// on one. Tapping rather than a dice button because every square is already
  /// a target and a room taps the screen anyway.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final here = _at(b);
    if (here >= b.cells.length - 1) return null;
    final roll = Random().nextInt(6) + 1;
    var to = here + roll;
    if (to >= b.cells.length) to = b.cells.length - 1;
    to = _jumps[to] ?? to;
    // Built rather than copyWith'd: `copyWith(face: null)` KEEPS the old
    // face, so the token stayed behind on the square it left and the board
    // grew a second one every move.
    String? faceAt(int j) {
      if (j == to) return _token;
      if (j == here) {
        return _jumps[j] == null ? null : (_jumps[j]! > j ? _ladder : _snake);
      }
      return b.cells[j].face;
    }

    return [
      for (var j = 0; j < b.cells.length; j++)
        BoardCell(
          label: b.cells[j].label,
          face: faceAt(j),
          state: CellState.shown,
          tint: j == to ? CellTint.live : CellTint.none,
        ),
    ];
  }

  @override
  String? titleFor(GridBoard b) =>
      _at(b) >= b.cells.length - 1 ? 'Home!' : null;

  @override
  String? noteFor(GridBoard b) {
    final at = _at(b);
    return at == 0 ? null : '${at + 1}';
  }
}
