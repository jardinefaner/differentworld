import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Whack-a-Mole.** One square pops. Tap it before the next one does.
///
/// The room shouts where it went and one pair of hands does the tapping —
/// which is more fun than it sounds, and the only game here that rewards
/// being quick rather than being right.
class WhackAMoleGame extends GridGame {
  const WhackAMoleGame();

  static const _mole = '🐹';

  @override
  String get id => 'whack-a-mole';

  @override
  String get title => 'Whack-a-Mole';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.amber);

  @override
  int get cols => 3;

  @override
  int get rows => 3;

  @override
  List<BoardCell> deal(ContentSource content) {
    final up = Random().nextInt(9);
    return [
      for (var i = 0; i < 9; i++)
        if (i == up)
          const BoardCell(face: _mole, state: CellState.shown)
        else
          const BoardCell(),
    ];
  }

  /// A hit moves the mole; a miss does nothing at all. Scoring lives in the
  /// `done` count, so the board is its own scoreboard.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    if (b.cells[i].face != _mole) return null;
    final hits = b.count(CellState.done) + 1;
    final r = Random();
    var next = r.nextInt(b.cells.length);
    if (next == i) next = (next + 1) % b.cells.length;
    return [
      for (var j = 0; j < b.cells.length; j++)
        if (j == next)
          const BoardCell(face: _mole, state: CellState.shown)
        else if (j < hits)
          const BoardCell(state: CellState.done)
        else
          const BoardCell(),
    ];
  }

  @override
  String? noteFor(GridBoard b) {
    final n = b.count(CellState.done);
    return n == 0 ? null : '$n';
  }
}
