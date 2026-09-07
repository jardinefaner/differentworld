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
///
/// **The board holds the secret.** It previously held none: the room
/// eliminated faces with nothing to converge on, so there was no answer to be
/// right or wrong about and the last face standing meant nothing. One face is
/// now chosen at deal and kept in the tally, and the closing line says
/// whether the room found it.
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

  /// Which face the board is thinking of. Stored as an index in the tally —
  /// never in a cell, because a cell reaches the screen and this must not.
  static int secretOf(GridBoard b) => b.score('secret');

  @override
  Map<String, int> get initialTally => {
    'secret': Random().nextInt(cols * rows),
  };

  @override
  List<BoardCell> deal(ContentSource content) {
    final picks = content.take(ContentKind.picture, cols * rows);
    final faces = [for (final p in picks) p.payload['image']! as String];
    // A short picture bank must still fill the board. Bingo already padded
    // for this reason; Guess Who did not, so a program with fewer than twelve
    // pictures got a board with holes — or, with none, an empty grid and a
    // game that cannot be played at all. Duplicating faces makes for an
    // easier round, which beats an unplayable one.
    while (faces.isNotEmpty && faces.length < cols * rows) {
      faces.addAll(List.of(faces));
    }
    faces.shuffle(Random());
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

  /// One face left standing — and now it can be RIGHT or wrong, because the
  /// board was thinking of somebody.
  @override
  String? outcomeFor(GridBoard b) {
    if (_left(b) != 1) return null;
    final standing = b.cells.indexWhere((c) => c.state != CellState.done);
    return standing == secretOf(b)
        ? 'That is who!'
        : 'Not this time — it was the other one';
  }

  @override
  String? titleFor(GridBoard b) => _left(b) == 1 ? 'That is who!' : null;

  @override
  String? noteFor(GridBoard b) {
    final n = _left(b);
    return n == b.cells.length ? null : '$n left';
  }

  int _left(GridBoard b) => b.count(CellState.shown);
}
