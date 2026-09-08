import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Scattergories.** One letter, six categories, and whatever the room can
/// come up with.
class ScattergoriesGame extends GridGame {
  const ScattergoriesGame();

  static const _categories = [
    'An animal',
    'Something you eat',
    'A place',
    'A colour',
    'Something in this room',
    'A name',
    'Something cold',
    'A job',
    'Something that moves',
    'A game',
  ];
  // No Q, X or Z — a letter nobody can use is a category wasted.
  static const _letters = 'ABCDEFGHILMNOPRSTW';

  @override
  String get id => 'scattergories';

  @override
  String get title => 'Scattergories';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.coral);

  @override
  int get cols => 2;

  @override
  int get rows => 3;

  @override
  String? get entryHint => 'An answer, then the next';

  static String letterOf(GridBoard b) =>
      b.cells.isEmpty ? '' : (b.cells.last.face ?? '');

  @override
  List<BoardCell> deal(ContentSource content) {
    final r = Random();
    final cats = List.of(_categories)..shuffle(r);
    final letter = _letters[r.nextInt(_letters.length)];
    return [
      for (var i = 0; i < cols * rows; i++)
        BoardCell(
          label: cats[i],
          state: CellState.shown,
          // The letter rides on the last cell, which is also a real category
          // square — the face is unused by this game, so it is free storage.
          face: i == cols * rows - 1 ? letter : null,
        ),
    ];
  }

  /// The letter is storage; the categories are the board.
  @override
  BoardCell present(BoardCell c) =>
      BoardCell(label: c.label, state: c.state, tint: c.tint);

  /// Typed answers fill the next empty category in order, so the room works
  /// down the board without anyone choosing where each one goes.
  /// **The rule of the game:** an answer has to start with the letter. This
  /// was not checked at all — any word was accepted for any category, so
  /// nothing could be wrong and there was nothing to play against.
  static bool _startsRight(GridBoard b, String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    return t[0].toUpperCase() == letterOf(b).toUpperCase();
  }

  /// Teams alternate on MISTAKES: a good answer keeps the board, a word that
  /// does not start with the letter passes it over.
  @override
  bool get alternates => true;

  @override
  bool handsOverAfterEntry(GridBoard before, String text) =>
      !_startsRight(before, text);

  /// A good answer scores for the team that gave it.
  @override
  Map<String, int> tallyAfterEntry(GridBoard before, String text) =>
      _startsRight(before, text) ? plusForTurn(before) : before.tally;

  @override
  List<BoardCell>? onEntry(GridBoard b, String text) {
    final next = b.cells.indexWhere((c) => c.tint == CellTint.none);
    if (next < 0) return null;
    if (!_startsRight(b, text)) {
      // A wrong answer is a move: it costs the turn. The category stays open
      // for the other team.
      return [for (final c in b.cells) c];
    }
    return b.withAt(
      next,
      b.cells[next].copyWith(
        label: '${b.cells[next].label}\n$text',
        tint: CellTint.right,
      ),
    );
  }

  @override
  List<BoardCell>? onPick(GridBoard b, int i) => null;

  /// Every category answered. The count was already on the board; nothing
  /// ever declared the round finished.
  @override
  String? outcomeFor(GridBoard b) =>
      b.cells.every((c) => c.tint == CellTint.right)
      ? 'All of them, with ${letterOf(b)}'
      : null;

  @override
  String? titleFor(GridBoard b) => 'Everything starts with ${letterOf(b)}';

  @override
  String? noteFor(GridBoard b) {
    final turn = turnLine(b);
    final score = scoreLine(b);
    if (score != null) return '$turn   ·   $score';
    return turn;
  }
}
