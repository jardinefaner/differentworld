import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Guess Who.** A board of faces. The room asks yes-or-no questions and
/// knocks out whoever does not fit, until one is left.
///
/// The only game here where elimination is the whole thing rather than the
/// ending — the board SHRINKING is the tension. `done` was already defined as
/// "resolved and out of play, drawn quieter", which is exactly that.
class GuessWhoGame extends GridGame {
  const GuessWhoGame();

  @override
  String get id => 'guess-who';

  @override
  String get title => 'Guess Who';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.plum);

  @override
  int get cols => 4;

  @override
  int get rows => 3;

  @override
  List<BoardCell> deal(ContentSource content) {
    final picks = content.take(ContentKind.picture, cols * rows);
    final faces = [for (final p in picks) p.payload['image']! as String]
      ..shuffle(Random());
    return [
      for (var i = 0; i < min(faces.length, cols * rows); i++)
        // Everyone is face-up from the start. You are not uncovering people,
        // you are ruling them out.
        BoardCell(face: faces[i], state: CellState.shown),
    ];
  }

  /// Knock out, or put back — a room changes its mind about whether the
  /// answer was "curly hair", and undoing has to be as easy as doing.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final c = b.cells[i];
    final next = c.state == CellState.done ? CellState.shown : CellState.done;
    return b.withAt(i, c.copyWith(state: next));
  }

  @override
  String? titleFor(GridBoard b) =>
      _left(b) == 1 ? 'That is who!' : 'Ask a question — rule them out';

  @override
  String? noteFor(GridBoard b) {
    final n = _left(b);
    return n == b.cells.length ? null : '$n left';
  }

  int _left(GridBoard b) => b.count(CellState.shown);
}
