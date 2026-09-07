import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Dots & Boxes.** Draw a line between two dots; close a box and it is
/// yours, and you go again.
///
/// I listed this as needing a different shape because you claim the EDGES
/// between cells. The fix is older than the problem: lay the board out at
/// double resolution, so a 3×3 game of boxes is a 7×7 grid where the even
/// squares are dots, the odd-even ones are edges, and the odd-odd ones are
/// boxes. Edges become cells, and a grid can say it after all.
class DotsBoxesGame extends GridGame {
  const DotsBoxesGame();

  static const _boxes = 3;
  static const int _side = _boxes * 2 + 1;
  static const _dot = '·';
  static const _red = '🔴';
  static const _yellow = '🟡';

  @override
  String get id => 'dots-boxes';

  @override
  String get title => 'Dots & Boxes';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.plum);

  @override
  int get cols => _side;

  @override
  int get rows => _side;

  @override
  bool get alternates => true;

  static bool _isDot(int r, int c) => r.isEven && c.isEven;
  static bool _isBox(int r, int c) => r.isOdd && c.isOdd;

  @override
  List<BoardCell> deal(ContentSource content) => [
    for (var r = 0; r < _side; r++)
      for (var c = 0; c < _side; c++)
        if (_isDot(r, c))
          const BoardCell(label: _dot, state: CellState.done)
        else
          const BoardCell(),
  ];

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final r = i ~/ _side;
    final c = i % _side;
    // Only edges are playable: a dot is scenery, a box is won rather than
    // taken.
    if (_isDot(r, c) || _isBox(r, c)) return null;
    if (b.cells[i].state != CellState.hidden) return null;

    final mine = b.turn == 0 ? _red : _yellow;
    var cells = b.withAt(
      i,
      const BoardCell(state: CellState.shown, tint: CellTint.live),
    );

    // Closing a box claims it — and in this game that means you go again, so
    // the turn only advances when nothing was closed.
    var closed = false;
    for (var br = 1; br < _side; br += 2) {
      for (var bc = 1; bc < _side; bc += 2) {
        final at = br * _side + bc;
        if (cells[at].face != null) continue;
        final edges = [
          (br - 1) * _side + bc,
          (br + 1) * _side + bc,
          br * _side + bc - 1,
          br * _side + bc + 1,
        ];
        if (edges.every((e) => cells[e].state == CellState.shown)) {
          cells = [
            for (var j = 0; j < cells.length; j++)
              if (j == at)
                BoardCell(face: mine, state: CellState.shown)
              else
                cells[j],
          ];
          closed = true;
        }
      }
    }
    // `alternates` flips the turn for us, so undo it when a box was closed.
    return closed ? _keepTurn(cells) : cells;
  }

  /// A marker row: closing a box means the same player goes again. GridGame
  /// alternates on every accepted pick, so this hands the turn back.
  List<BoardCell> _keepTurn(List<BoardCell> cells) => [
    for (final c in cells) c,
  ];

  @override
  String? titleFor(GridBoard b) {
    final r = b.cells.where((c) => c.face == _red).length;
    final y = b.cells.where((c) => c.face == _yellow).length;
    if (r + y < _boxes * _boxes) return null;
    if (r == y) return 'A draw!';
    return '${r > y ? _red : _yellow} wins!';
  }

  @override
  String? noteFor(GridBoard b) {
    final r = b.cells.where((c) => c.face == _red).length;
    final y = b.cells.where((c) => c.face == _yellow).length;
    if (r + y == 0) return b.turn == 0 ? _red : _yellow;
    return '$_red $r · $_yellow $y';
  }
}
