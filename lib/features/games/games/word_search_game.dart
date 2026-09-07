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
    // A placed letter is marked — in `face`, which this game does not
    // otherwise use, NOT inside the label. The grid knew where the words were
    // while it was building itself and then threw that away, which is why it
    // could never tell when they had all been found. Keeping the marker out
    // of the label matters: the label IS the letter, and anything that reads
    // it (a test, a renderer, a future feature) should see one character.
    return [
      for (final ch in grid)
        BoardCell(
          label: ch ?? alphabet[r.nextInt(alphabet.length)],
          face: ch == null ? null : _placed,
          state: CellState.shown,
        ),
    ];
  }

  /// Tap a letter to ring it; tap again to let it go. The room decides what
  /// counts as a word — the board is not going to argue.
  /// Marks a letter that belongs to a hidden word. Storage only.
  static const _placed = 'w';

  /// The marker never reaches a room — a board that drew it would circle
  /// every answer in the grid.
  @override
  BoardCell present(BoardCell c) =>
      BoardCell(label: c.label, state: c.state, tint: c.tint);

  /// Every letter that belongs to a word, ringed.
  @override
  String? outcomeFor(GridBoard b) {
    final inWord = b.cells.where((c) => c.face == _placed);
    if (inWord.isEmpty) return null;
    return inWord.every((c) => c.tint == CellTint.right)
        ? 'Every word found'
        : null;
  }

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
