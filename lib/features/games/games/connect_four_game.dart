import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Connect Four.** Two teams, counters fall down a column, four in a line
/// wins.
///
/// The one classic here with real gravity: a tap picks a COLUMN and the
/// counter lands at the bottom of it. That is the only rule the base does not
/// already give, and it is six lines.
class ConnectFourGame extends GridGame {
  const ConnectFourGame();

  static const _red = '🔴';
  static const _yellow = '🟡';

  @override
  String get id => 'connect-four';

  @override
  String get title => 'Connect Four';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.coral);

  @override
  int get cols => 7;

  @override
  int get rows => 6;

  @override
  bool get alternates => true;

  @override
  List<BoardCell> deal(ContentSource content) =>
      List.filled(cols * rows, const BoardCell());

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final col = i % b.cols;
    // Gravity: whichever row was tapped, the counter falls to the lowest
    // empty square in that column. Declining a full column is what keeps a
    // stray tap from costing a turn.
    for (var r = b.rows - 1; r >= 0; r--) {
      final at = r * b.cols + col;
      if (b.cells[at].state == CellState.hidden) {
        return b.withAt(
          at,
          BoardCell(
            face: b.turn == 0 ? _red : _yellow,
            state: CellState.shown,
          ),
        );
      }
    }
    return null;
  }

  @override
  String? titleFor(GridBoard b) {
    final w = _winner(b);
    if (w != null) return '$w wins!';
    return null;
  }

  @override
  String? noteFor(GridBoard b) =>
      _winner(b) != null ? null : '${b.turn == 0 ? _red : _yellow} to play';

  /// Four in a row, any direction. Walks from every square along the four
  /// directions that can start a line; the opposite four are the same lines
  /// read backwards.
  String? _winner(GridBoard b) {
    const dirs = [(1, 0), (0, 1), (1, 1), (1, -1)];
    for (var r = 0; r < b.rows; r++) {
      for (var c = 0; c < b.cols; c++) {
        final face = b.cells[r * b.cols + c].face;
        if (face == null) continue;
        for (final (dc, dr) in dirs) {
          var n = 0;
          for (var k = 0; k < 4; k++) {
            final rr = r + dr * k;
            final cc = c + dc * k;
            if (rr < 0 || rr >= b.rows || cc < 0 || cc >= b.cols) break;
            if (b.cells[rr * b.cols + cc].face != face) break;
            n++;
          }
          if (n == 4) return face;
        }
      }
    }
    return null;
  }
}
