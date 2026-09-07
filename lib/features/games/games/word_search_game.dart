import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Word Search.** A grid of letters with words hidden across and down; tap
/// the letters of one you have spotted.
class WordSearchGame extends GridGame {
  const WordSearchGame();

  static const _size = 8;
  static const _fallback = ['CAT', 'SUN', 'TREE', 'BOOK', 'STAR'];

  @override
  String get id => 'word-search';

  @override
  String get title => 'Word Search';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.sage);

  @override
  int get cols => _size;

  @override
  int get rows => _size;

  @override
  List<BoardCell> deal(ContentSource content) {
    final r = Random();
    final grid = List<String?>.filled(_size * _size, null);
    // Placed across and down only — a diagonal is a lot to ask of a six year
    // old, and this deck runs from four up.
    for (final w in _fallback) {
      for (var attempt = 0; attempt < 40; attempt++) {
        final down = r.nextBool();
        final maxStart = _size - w.length;
        if (maxStart < 0) break;
        final line = r.nextInt(_size);
        final start = r.nextInt(maxStart + 1);
        int posOf(int k) =>
            down ? (start + k) * _size + line : line * _size + start + k;
        final at = [for (var k = 0; k < w.length; k++) posOf(k)];
        // Only place where it agrees with whatever is already there, so
        // crossings work and nothing is overwritten into nonsense.
        final ok = [
          for (var k = 0; k < w.length; k++)
            grid[at[k]] == null || grid[at[k]] == w[k],
        ].every((e) => e);
        if (!ok) continue;
        for (var k = 0; k < w.length; k++) {
          grid[at[k]] = w[k];
        }
        break;
      }
    }
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return [
      for (final ch in grid)
        BoardCell(
          label: ch ?? alphabet[r.nextInt(alphabet.length)],
          state: CellState.shown,
        ),
    ];
  }

  /// Tap a letter to ring it; tap again to let it go. The room decides what
  /// counts as a word — the board is not going to argue.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final c = b.cells[i];
    final on = c.tint == CellTint.right;
    return b.withAt(
      i,
      c.copyWith(tint: on ? CellTint.none : CellTint.right),
    );
  }

  @override
  String? noteFor(GridBoard b) {
    final n = b.cells.where((c) => c.tint == CellTint.right).length;
    return n == 0 ? null : '$n ringed';
  }
}
