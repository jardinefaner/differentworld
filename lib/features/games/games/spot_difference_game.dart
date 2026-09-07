import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Spot the Difference.** Two sets of pictures, one thing changed.
///
/// The last of the six I said needed a different shape, and the last one that
/// did not. Two boards side by side is one board twice as wide — the same
/// trick as laying Dots & Boxes out at double resolution. Every game on that
/// list was a grid; the shape was fine and my reading of it was not.
class SpotDifferenceGame extends GridGame {
  const SpotDifferenceGame();

  static const _half = 3;

  @override
  String get id => 'spot-difference';

  @override
  String get title => 'Spot the Difference';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.rose);

  /// Two 3×3 boards, side by side, with a gap column between them so the room
  /// reads it as two things rather than one wide one.
  @override
  int get cols => _half * 2 + 1;

  @override
  int get rows => _half;

  @override
  List<BoardCell> deal(ContentSource content) {
    final r = Random();
    final picks = content.take(ContentKind.picture, _half * _half + 1);
    final faces = [for (final p in picks) p.payload['image']! as String];
    if (faces.length < _half * _half + 1) {
      return const [];
    }
    final changed = r.nextInt(_half * _half);
    final swap = faces.last;
    return [
      for (var row = 0; row < _half; row++)
        for (var c = 0; c < cols; c++)
          if (c == _half)
            const BoardCell(state: CellState.done) // the gap
          else
            BoardCell(
              face: (c > _half && row * _half + (c - _half - 1) == changed)
                  ? swap
                  : faces[row * _half + (c > _half ? c - _half - 1 : c)],
              state: CellState.shown,
              // The answer rides on BOTH copies of the changed square, and
              // present() hides it until somebody taps.
              label: (row * _half + (c > _half ? c - _half - 1 : c)) == changed
                  ? 'x'
                  : null,
            ),
    ];
  }

  /// The marker is storage. A board that showed it would be answering its own
  /// question.
  @override
  BoardCell present(BoardCell c) =>
      BoardCell(face: c.face, state: c.state, tint: c.tint);

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    if (b.cells[i].state == CellState.done) return null;
    final right = b.cells[i].label == 'x';
    if (!right) {
      // A wrong guess flashes and clears on the next tap, so the board does
      // not fill up with everywhere the room has already looked.
      return [
        for (var j = 0; j < b.cells.length; j++)
          b.cells[j].copyWith(tint: j == i ? CellTint.wrong : CellTint.none),
      ];
    }
    return [
      for (final c in b.cells)
        c.copyWith(tint: c.label == 'x' ? CellTint.right : CellTint.none),
    ];
  }

  @override
  String? titleFor(GridBoard b) =>
      b.cells.any((c) => c.tint == CellTint.right) ? 'Found it!' : null;
}
