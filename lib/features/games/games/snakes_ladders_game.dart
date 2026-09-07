import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Snakes & Ladders.** Two teams roll, move, and hope.
///
/// It had ONE token, which made it a solitaire walk to square 36 with no
/// decision in it and nobody to beat — the least game-like thing in the deck.
/// Two tokens make it the race it actually is: the room takes turns, and a
/// ladder or a snake happens to somebody in particular.
///
/// I listed this as needing a different shape because a token moves along a
/// path. It does not: the path IS a grid, and the token is a face on one
/// square. The board was a grid the whole time.
class SnakesLaddersGame extends GridGame {
  const SnakesLaddersGame();

  static const _tokens = ['🔴', '🔵'];

  /// Both teams on one square. A cell holds one face, so a shared square
  /// draws both — otherwise a token would silently vanish under the other.
  static const _both = '🔴🔵';
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
  bool get alternates => true;

  @override
  List<String> get sides => _tokens;

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
  List<BoardCell> deal(ContentSource content) => _paint([0, 0]);

  /// The board for a pair of positions. Built whole rather than patched,
  /// because `copyWith(face: null)` KEEPS the old face — the trap this file
  /// already learned once, when the token stayed behind and the board grew a
  /// second one every move.
  static List<BoardCell> _paint(List<int> at) => [
    for (var i = 0; i < 36; i++)
      BoardCell(
        label: '${i + 1}',
        face: _faceAt(i, at),
        state: CellState.shown,
      ),
  ];

  static String? _faceAt(int i, List<int> at) {
    final here = [
      for (var s = 0; s < at.length; s++)
        if (at[s] == i) s,
    ];
    if (here.length > 1) return _both;
    if (here.length == 1) return _tokens[here.first];
    final jump = _jumps[i];
    if (jump == null) return null;
    return jump > i ? _ladder : _snake;
  }

  /// Where each side stands, read back off the board.
  static List<int> positionsOf(GridBoard b) {
    final out = [0, 0];
    for (var i = 0; i < b.cells.length; i++) {
      final f = b.cells[i].face;
      if (f == _both) {
        out[0] = i;
        out[1] = i;
      } else if (f == _tokens[0]) {
        out[0] = i;
      } else if (f == _tokens[1]) {
        out[1] = i;
      }
    }
    return out;
  }

  /// Any tap is a roll — one to six, then the snake or the ladder if you land
  /// on one. Tapping rather than a dice button because every square is already
  /// a target and a room taps the screen anyway.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final at = positionsOf(b);
    final side = b.turn % _tokens.length;
    if (at[side] >= 36 - 1) return null;
    final roll = Random().nextInt(6) + 1;
    var to = at[side] + roll;
    if (to >= 36) to = 36 - 1;
    to = _jumps[to] ?? to;
    final next = [...at]..[side] = to;
    return [
      for (var j = 0; j < 36; j++)
        BoardCell(
          label: '${j + 1}',
          face: _faceAt(j, next),
          state: CellState.shown,
          tint: j == to ? CellTint.live : CellTint.none,
        ),
    ];
  }

  /// First team home. It is a RACE now, so the ending names who won.
  @override
  String? outcomeFor(GridBoard b) {
    final at = positionsOf(b);
    for (var s = 0; s < at.length; s++) {
      if (at[s] >= 36 - 1) return '${_tokens[s]} is home!';
    }
    return null;
  }

  @override
  String? titleFor(GridBoard b) => outcomeFor(b);

  /// Whose go, and where both teams stand — the two things a room watching a
  /// race wants without asking.
  @override
  String? noteFor(GridBoard b) {
    final at = positionsOf(b);
    final turn = turnLine(b);
    if (at[0] == 0 && at[1] == 0) return turn;
    final where = [
      for (var s = 0; s < at.length; s++) '${_tokens[s]} ${at[s] + 1}',
    ].join('  ·  ');
    return turn == null ? where : '$turn   ·   $where';
  }
}
