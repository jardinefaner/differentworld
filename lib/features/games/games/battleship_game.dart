import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Battleship.** Ships hidden on a lettered grid; the room calls a square
/// and finds out.
///
/// The A1–D4 labels already existed for Reveal the Picture, for exactly this
/// reason — a room calling out a coordinate. This game is the closest thing
/// to free in the deck: the same grid, the same labels, the same three states.
class BattleshipGame extends GridGame {
  const BattleshipGame();

  static const _hit = '💥';
  static const _miss = '🌊';

  /// How many squares are ships. Five on a 5×5 keeps a round to a couple of
  /// minutes, which is the length of a brain break.
  static const _ships = 5;

  @override
  String get id => 'battleship';

  @override
  String get title => 'Battleship';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.slate);

  @override
  int get cols => 5;

  @override
  int get rows => 5;

  /// The label a room says out loud. Column letter, row number — B3.
  static String label(int i, int cols) =>
      '${String.fromCharCode(65 + i % cols)}${i ~/ cols + 1}';

  @override
  List<BoardCell> deal(ContentSource content) {
    final r = Random();
    final ships = <int>{};
    while (ships.length < _ships) {
      ships.add(r.nextInt(cols * rows));
    }
    return [
      for (var i = 0; i < cols * rows; i++)
        BoardCell(
          label: label(i, cols),
          // The ship rides in the FACE, unseen while the cell is hidden. The
          // wire carries it either way — this is a room playing against the
          // board, not two players hiding fleets from each other, so there is
          // nothing to keep secret from the screen.
          face: ships.contains(i) ? _hit : _miss,
        ),
    ];
  }

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    // Already fired on. Declining the tap is what stops a double-tap from
    // reading as two shots.
    if (b.cells[i].state != CellState.hidden) return null;
    return b.withAt(i, b.cells[i].copyWith(state: CellState.shown));
  }

  @override
  String? titleFor(GridBoard b) => _sunk(b) == _ships ? 'All hit!' : null;

  @override
  String? noteFor(GridBoard b) {
    final hit = _sunk(b);
    final shots = b.cells.where((c) => c.state != CellState.hidden).length;
    if (shots == 0) return 'Call a square';
    return '$hit of $_ships · $shots ${shots == 1 ? 'shot' : 'shots'}';
  }

  int _sunk(GridBoard b) => b.cells
      .where((c) => c.state != CellState.hidden && c.face == _hit)
      .length;
}
