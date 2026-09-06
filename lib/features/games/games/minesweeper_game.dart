import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Minesweeper.** Uncover squares; the number says how many mines touch it.
///
/// Deliberately gentle — a 6×5 board with five mines, and hitting one ends
/// the round rather than exploding it. The room argues about the next square,
/// which is the part worth having.
class MinesweeperGame extends GridGame {
  const MinesweeperGame();

  static const _mine = '💣';
  static const _mines = 5;

  @override
  String get id => 'minesweeper';

  @override
  String get title => 'Minesweeper';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.slate);

  @override
  int get cols => 6;

  @override
  int get rows => 5;

  @override
  List<BoardCell> deal(ContentSource content) {
    final r = Random();
    final mines = <int>{};
    while (mines.length < _mines) {
      mines.add(r.nextInt(cols * rows));
    }
    return [
      for (var i = 0; i < cols * rows; i++)
        BoardCell(
          face: mines.contains(i) ? _mine : null,
          // The count rides in the label, unseen until the square is
          // uncovered — no new field needed for the number that IS the game.
          label: mines.contains(i) ? null : '${_touching(mines, i)}',
        ),
    ];
  }

  int _touching(Set<int> mines, int i) {
    final r = i ~/ cols;
    final c = i % cols;
    var n = 0;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final rr = r + dr;
        final cc = c + dc;
        if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) continue;
        if (mines.contains(rr * cols + cc)) n++;
      }
    }
    return n;
  }

  /// A covered square gives nothing away — not its count, not whether it is
  /// the mine. Both are stored from the deal so the reducer stays pure; this
  /// is where they stop being visible.
  @override
  BoardCell present(BoardCell c) =>
      c.state == CellState.hidden ? const BoardCell() : c;

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    if (b.cells[i].state != CellState.hidden) return null;
    final hit = b.cells[i].face == _mine;
    if (hit) {
      // Show every mine, so the room sees where they all were. That is the
      // interesting part of losing.
      return [
        for (final c in b.cells)
          if (c.face == _mine)
            c.copyWith(state: CellState.shown, tint: CellTint.wrong)
          else
            c,
      ];
    }
    return b.withAt(
      i,
      b.cells[i].copyWith(state: CellState.shown, tint: CellTint.right),
    );
  }

  @override
  String? titleFor(GridBoard b) => _blown(b) ? 'Found one!' : null;

  @override
  String? noteFor(GridBoard b) {
    if (_blown(b)) return null;
    final safe = b.cells.where((c) => c.face != _mine).length;
    final open = b.cells
        .where((c) => c.face != _mine && c.state != CellState.hidden)
        .length;
    return open == safe ? 'All clear!' : '$open of $safe safe';
  }

  bool _blown(GridBoard b) =>
      b.cells.any((c) => c.face == _mine && c.state != CellState.hidden);
}
