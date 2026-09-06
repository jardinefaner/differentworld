import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Four Corners.** The corners of the room are the four squares; everyone
/// goes and stands in one, and the screen shows where the room landed.
///
/// The only game here where the board is the ROOM. Nothing is hidden and
/// nobody wins — it is a way of asking a question that gets everybody on
/// their feet, which is the point of a brain break.
class FourCornersGame extends GridGame {
  const FourCornersGame();

  @override
  String get id => 'four-corners';

  @override
  String get title => 'Four Corners';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.sage);

  @override
  int get cols => 2;

  @override
  int get rows => 2;

  @override
  List<BoardCell> deal(ContentSource content) => const [
    BoardCell(label: 'Front left', state: CellState.shown),
    BoardCell(label: 'Front right', state: CellState.shown),
    BoardCell(label: 'Back left', state: CellState.shown),
    BoardCell(label: 'Back right', state: CellState.shown),
  ];

  /// A tap marks the corner the room chose. One at a time — tapping another
  /// moves the mark rather than adding a second, because the room is standing
  /// in one place.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) => [
    for (var j = 0; j < b.cells.length; j++)
      b.cells[j].copyWith(
        tint: j == i ? CellTint.live : CellTint.none,
        state: CellState.shown,
      ),
  ];

  @override
  String? titleFor(GridBoard b) => 'Go and stand in a corner';
}
