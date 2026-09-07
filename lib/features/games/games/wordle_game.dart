import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Wordle.** Six goes at a five-letter word; the room shouts guesses and
/// one person types.
///
/// The tint vocabulary was built for exactly this and named for it: right,
/// close, wrong.
class WordleGame extends GridGame {
  const WordleGame();

  static const _words = [
    'PLANT',
    'BRAVE',
    'CHASE',
    'SHINE',
    'GRAPE',
    'STORM',
    'TRAIN',
    'CLOUD',
    'SMILE',
    'BEACH',
    'HORSE',
    'LIGHT',
    'MUSIC',
    'RIVER',
  ];

  @override
  String get id => 'wordle';

  @override
  String get title => 'Wordle';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.sage);

  @override
  int get cols => 5;

  @override
  int get rows => 6;

  @override
  String? get entryHint => 'Five letters';

  @override
  int? get entryLength => 5;

  /// The answer rides in the first empty row's label — storage, blanked by
  /// [present] before anything is drawn.
  static String answerOf(GridBoard b) =>
      b.cells.isEmpty ? '' : (b.cells.last.label ?? '');

  @override
  List<BoardCell> deal(ContentSource content) {
    final word = _words[Random().nextInt(_words.length)];
    return [
      for (var i = 0; i < cols * rows; i++)
        BoardCell(label: i == cols * rows - 1 ? word : null),
    ];
  }

  /// The board is storage as well as display: the last cell holds the answer,
  /// and every unplayed cell is blank. Neither may reach the room.
  @override
  BoardCell present(BoardCell c) => c.tint == CellTint.none
      ? const BoardCell()
      : BoardCell(label: c.label, state: CellState.shown, tint: c.tint);

  int _rowsUsed(GridBoard b) {
    for (var r = 0; r < b.rows; r++) {
      if (b.cells[r * b.cols].tint == CellTint.none) return r;
    }
    return b.rows;
  }

  @override
  List<BoardCell>? onEntry(GridBoard b, String text) {
    final guess = text.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
    if (guess.length != cols) return null;
    final row = _rowsUsed(b);
    if (row >= b.rows || _solved(b)) return null;
    final answer = answerOf(b);

    // Two passes, which is the part everyone gets wrong: exact matches are
    // claimed FIRST, so a repeated letter cannot be marked "close" against an
    // answer letter that a later exact match already used.
    final left = <String, int>{};
    for (var i = 0; i < cols; i++) {
      if (guess[i] != answer[i]) {
        left[answer[i]] = (left[answer[i]] ?? 0) + 1;
      }
    }
    final tints = <CellTint>[];
    for (var i = 0; i < cols; i++) {
      if (guess[i] == answer[i]) {
        tints.add(CellTint.right);
      } else if ((left[guess[i]] ?? 0) > 0) {
        left[guess[i]] = left[guess[i]]! - 1;
        tints.add(CellTint.close);
      } else {
        tints.add(CellTint.wrong);
      }
    }
    return [
      for (var i = 0; i < b.cells.length; i++)
        if (i ~/ cols == row)
          BoardCell(
            label: guess[i % cols],
            state: CellState.shown,
            tint: tints[i % cols],
          )
        else
          b.cells[i],
    ];
  }

  bool _solved(GridBoard b) {
    for (var r = 0; r < b.rows; r++) {
      final row = [for (var c = 0; c < b.cols; c++) b.cells[r * b.cols + c]];
      if (row.every((c) => c.tint == CellTint.right)) return true;
    }
    return false;
  }

  @override
  List<BoardCell>? onPick(GridBoard b, int i) => null;

  @override
  String? titleFor(GridBoard b) {
    if (_solved(b)) return 'Got it!';
    if (_rowsUsed(b) >= b.rows) return answerOf(b);
    return null;
  }
}
