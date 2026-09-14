import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/room_beat.dart';
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

  /// The sides by the colour of their disc — what a room actually shouts.
  @override
  List<String> get sides => const ['Red', 'Yellow'];

  /// A rack of holes, and a disc drops down its column — the look every
  /// Connect Four has ever had. The renderer does the drop.
  @override
  ShapeStyle get style => ShapeStyle.holes;

  /// The disc IS the slot: the faces (🔴 / 🟡) stay as the board's storage
  /// and the reducer's language, but the room sees a red or yellow disc, not
  /// an emoji in a white square.
  @override
  BoardCell present(BoardCell c) => c.face == null
      ? c
      : BoardCell(state: c.state, tint: c.tint, slot: c.face == _red ? 1 : 2);

  @override
  RunScript get howToPlay => const [
    RoomBeat('We are playing Connect Four'),
    RoomBeat('Get four in a row to win', detail: 'Across, up, or slanted'),
    // The rule a room of four-year-olds cannot guess from looking, and the
    // one that makes the first minute confusing if nobody says it: you pick a
    // COLUMN, not a square.
    RoomBeat('Pick a column', detail: 'Your circle drops to the bottom'),
    RoomBeat('Team 1 starts', detail: 'The red circles'),
  ];

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
        final next = b.withAt(
          at,
          BoardCell(
            face: b.turn == 0 ? _red : _yellow,
            state: CellState.shown,
          ),
        );
        // The winning four light up, so the room sees WHERE the line is
        // rather than only that somebody won.
        final line = _winningLine(b.copyWith(cells: next));
        if (line == null) return next;
        return [
          for (var j = 0; j < next.length; j++)
            if (line.contains(j))
              next[j].copyWith(tint: CellTint.live)
            else
              next[j],
        ];
      }
    }
    return null;
  }

  /// Four in a row. The line was already computed for the board's title —
  /// it simply never stamped `done`, so the round ran forever.
  @override
  String? outcomeFor(GridBoard b) => titleFor(b);

  @override
  String? titleFor(GridBoard b) {
    final w = _winner(b);
    if (w != null) return '${w == _red ? sides[0] : sides[1]} wins!';
    return null;
  }

  // No noteFor: the base's turnLine says "Red to play" from [sides].

  /// Four in a row, any direction. Walks from every square along the four
  /// directions that can start a line; the opposite four are the same lines
  /// read backwards.
  String? _winner(GridBoard b) {
    final line = _winningLine(b);
    return line == null ? null : b.cells[line.first].face;
  }

  /// The four squares of the winning line, or null.
  Set<int>? _winningLine(GridBoard b) {
    const dirs = [(1, 0), (0, 1), (1, 1), (1, -1)];
    for (var r = 0; r < b.rows; r++) {
      for (var c = 0; c < b.cols; c++) {
        final face = b.cells[r * b.cols + c].face;
        if (face == null) continue;
        for (final (dc, dr) in dirs) {
          final run = <int>{};
          for (var k = 0; k < 4; k++) {
            final rr = r + dr * k;
            final cc = c + dc * k;
            if (rr < 0 || rr >= b.rows || cc < 0 || cc >= b.cols) break;
            if (b.cells[rr * b.cols + cc].face != face) break;
            run.add(rr * b.cols + cc);
          }
          if (run.length == 4) return run;
        }
      }
    }
    return null;
  }
}
