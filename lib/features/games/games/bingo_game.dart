import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Bingo.** A card of pictures; tap each as it is called. Four in a line
/// wins, and the room shouts it.
///
/// The oldest kind of game in the deck and the cheapest to add — it is a board
/// and one rule, and everything else comes from [GridGame].
class BingoGame extends GridGame {
  const BingoGame();

  @override
  String get id => 'bingo';

  @override
  String get title => 'Bingo';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.amber);

  @override
  int get cols => 4;

  @override
  int get rows => 4;

  @override
  List<BoardCell> deal(ContentSource content) {
    final picks = content.take(ContentKind.picture, cols * rows);
    final faces = [for (final p in picks) p.payload['image']! as String];
    // A short bank should still fill the card rather than leave holes — a
    // half-empty bingo card reads as broken, not as a short deck.
    while (faces.length < cols * rows) {
      if (faces.isEmpty) {
        faces.add('★');
      } else {
        faces.addAll(List.of(faces));
      }
    }
    faces.shuffle(Random());
    return [
      for (var i = 0; i < cols * rows; i++)
        BoardCell(face: faces[i], state: CellState.shown),
    ];
  }

  /// Every square starts face-up — you are not uncovering anything, you are
  /// crossing off. So a tap moves shown → done, and a second tap undoes it,
  /// because somebody always mishears a call.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final c = b.cells[i];
    // A second tap undoes it, because somebody always mishears a call.
    final next = c.state == CellState.done ? CellState.shown : CellState.done;
    return b.withAt(i, c.copyWith(state: next));
  }

  @override
  String? titleFor(GridBoard b) =>
      _hasLine(b) ? 'Bingo!' : 'Cross them off as they are called';

  @override
  String? noteFor(GridBoard b) {
    final n = b.count(CellState.done);
    return n == 0 ? null : '$n of ${b.cells.length}';
  }

  /// A line is the win, so the board has to know what one is — rows, columns
  /// and both diagonals.
  bool _hasLine(GridBoard b) {
    bool done(int i) => b.cells[i].state == CellState.done;
    for (var r = 0; r < b.rows; r++) {
      if (List.generate(b.cols, (c) => r * b.cols + c).every(done)) return true;
    }
    for (var c = 0; c < b.cols; c++) {
      if (List.generate(b.rows, (r) => r * b.cols + c).every(done)) return true;
    }
    final n = min(b.cols, b.rows);
    if (List.generate(n, (k) => k * b.cols + k).every(done)) return true;
    if (List.generate(n, (k) => k * b.cols + (b.cols - 1 - k)).every(done)) {
      return true;
    }
    return false;
  }
}
