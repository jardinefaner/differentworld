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

  /// Two teams call squares in turn. Solitaire, this was one person tapping
  /// twenty-five boxes; with sides it is a room arguing about where the ships
  /// are and one pair of hands entering the call.
  @override
  bool get alternates => true;

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
          // The ship rides in the FACE. It is NOT automatically unseen while
          // the cell is hidden — the renderer draws a face whenever there is
          // one, whatever the state — so [present] does the hiding. Without
          // that override every ship was visible from the first frame AND the
          // coordinate labels never rendered, because a cell with a face
          // never shows its label. The whole game was on the screen.
          face: ships.contains(i) ? _hit : _miss,
        ),
    ];
  }

  /// A square not yet fired on shows its COORDINATE, not its contents. This
  /// is the whole game: the room calls "B3" and finds out.
  @override
  BoardCell present(BoardCell c) =>
      c.state == CellState.hidden ? BoardCell(label: c.label, tint: c.tint) : c;

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    // Already fired on. Declining the tap is what stops a double-tap from
    // reading as two shots.
    if (b.cells[i].state != CellState.hidden) return null;
    return b.withAt(i, b.cells[i].copyWith(state: CellState.shown));
  }

  /// A hit scores for whoever called it.
  @override
  Map<String, int> tallyAfterPick(GridBoard before, int i) =>
      (before.cells[i].state == CellState.hidden &&
          before.cells[i].face == _hit)
      ? plusForTurn(before)
      : before.tally;

  /// Every ship found — and now it matters WHO found them.
  @override
  String? outcomeFor(GridBoard b) {
    if (_sunk(b) != _ships) return null;
    final a = scoreOf(b, 0);
    final c = scoreOf(b, 1);
    if (a == c) return 'All hit — a draw at $a each';
    return '${sides[a > c ? 0 : 1]} wins, $a–$c';
  }

  @override
  String? titleFor(GridBoard b) => _sunk(b) == _ships ? 'All hit!' : null;

  @override
  String? noteFor(GridBoard b) {
    final score = scoreLine(b);
    final turn = turnLine(b);
    if (score != null && turn != null) return '$turn   ·   $score';
    return _legacyNote(b) ?? turn;
  }

  String? _legacyNote(GridBoard b) {
    final hit = _sunk(b);
    final shots = b.cells.where((c) => c.state != CellState.hidden).length;
    if (shots == 0) return null;
    return '$hit of $_ships · $shots ${shots == 1 ? 'shot' : 'shots'}';
  }

  int _sunk(GridBoard b) => b.cells
      .where((c) => c.state != CellState.hidden && c.face == _hit)
      .length;
}
