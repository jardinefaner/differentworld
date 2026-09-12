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
  /// The four corners are the four ANSWERS, when the room has written a
  /// question. Without one the board showed four positions and asked nothing,
  /// so the activity depended entirely on the adult inventing a question on
  /// the spot — the corners were furniture.
  ///
  /// The question rides in cell 0's `face`, which `present` strips: a face is
  /// storage here, and the room reads the question from the title.
  @override
  List<BoardCell> deal(ContentSource content) {
    const positions = ['Front left', 'Front right', 'Back left', 'Back right'];
    final picked = content.take(ContentKind.fourCorners, 1);
    if (picked.isEmpty) {
      return [
        for (final p in positions) BoardCell(label: p, state: CellState.shown),
      ];
    }
    final p = picked.first.payload;
    String opt(String key, int i) {
      final v = p[key];
      return (v is String && v.trim().isNotEmpty) ? v.trim() : positions[i];
    }

    final q = (p['question'] as String?)?.trim() ?? '';
    return [
      for (final (i, key) in ['a', 'b', 'c', 'd'].indexed)
        BoardCell(
          label: opt(key, i),
          face: i == 0 && q.isNotEmpty ? q : null,
          state: CellState.shown,
        ),
    ];
  }

  /// The question is storage, not a face to draw — the renderer would paint it
  /// over the first corner and hide that corner's label.
  @override
  BoardCell present(BoardCell c) =>
      BoardCell(label: c.label, state: c.state, tint: c.tint);

  /// The question, above the corners, where the room reads it.
  @override
  String? titleFor(GridBoard b) {
    final q = b.cells.isEmpty ? null : b.cells.first.face;
    return (q == null || q.isEmpty) ? null : q;
  }

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

  // No title. Four labelled corners on a screen called Four Corners is the
  // instruction; saying it as well is the sign on the wall.
}
