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

  /// Teams alternate hunting. One person ringing letters is a worksheet;
  /// two teams taking turns is a race the room shouts through.
  @override
  bool get alternates => true;

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
    final placed = <int, int>{}; // cell → word index
    for (var wi = 0; wi < _fallback.length; wi++) {
      final w = _fallback[wi];
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
          placed[at[k]] = wi;
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
      for (var i = 0; i < grid.length; i++)
        BoardCell(
          label: grid[i] ?? alphabet[r.nextInt(alphabet.length)],
          // WHICH word, not merely "in a word" — the board has to be able to
          // say "CAT is found" and cross it off the list.
          face: placed[i] == null ? null : '$_placed${placed[i]}',
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

  /// Which words are fully ringed.
  static Set<int> _found(GridBoard b) {
    final byWord = <int, List<BoardCell>>{};
    for (final c in b.cells) {
      final f = c.face;
      if (f == null || !f.startsWith(_placed)) continue;
      final wi = int.tryParse(f.substring(_placed.length));
      if (wi == null) continue;
      (byWord[wi] ??= []).add(c);
    }
    return {
      for (final e in byWord.entries)
        if (e.value.every((c) => c.tint == CellTint.right)) e.key,
    };
  }

  /// Which words are ON this board at all — a word the grid could not fit is
  /// not one the room should be asked to find.
  static Set<int> _onBoard(GridBoard b) {
    final out = <int>{};
    for (final c in b.cells) {
      final f = c.face;
      if (f == null || !f.startsWith(_placed)) continue;
      final wi = int.tryParse(f.substring(_placed.length));
      if (wi != null) out.add(wi);
    }
    return out;
  }

  /// **The list.** Without it the room was asked to find words it was never
  /// told — the grid hid five words and showed nobody what they were, which
  /// is not a hard game, it is an impossible one. Found words are struck
  /// through, so the line doubles as the score.
  @override
  String? titleFor(GridBoard b) {
    final on = _onBoard(b).toList()..sort();
    if (on.isEmpty) return null;
    final found = _found(b);
    return [
      for (final wi in on)
        if (found.contains(wi)) '✓ ${_fallback[wi]}' else _fallback[wi],
    ].join('   ');
  }

  /// Completing a word scores for the team that ringed the last letter.
  @override
  Map<String, int> tallyAfterPick(GridBoard before, int i) {
    final c = before.cells[i];
    if (c.face == null || c.tint == CellTint.right) return before.tally;
    // Would this ring finish a word?
    final after = before.copyWith(
      cells: before.withAt(i, c.copyWith(tint: CellTint.right)),
    );
    return _found(after).length > _found(before).length
        ? plusForTurn(before)
        : before.tally;
  }

  @override
  String? outcomeFor(GridBoard b) {
    final on = _onBoard(b);
    if (on.isEmpty) return null;
    if (_found(b).length != on.length) return null;
    final a = scoreOf(b, 0);
    final c = scoreOf(b, 1);
    if (a == c) return 'Every word found — $a each';
    return '${sides[a > c ? 0 : 1]} found more, $a–$c';
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
    final turn = turnLine(b);
    final score = scoreLine(b);
    if (score != null) return '$turn   ·   $score';
    return turn;
  }
}
