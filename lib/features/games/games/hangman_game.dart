import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Hangman.** The alphabet is the board; the word is the note above it.
///
/// No gallows — the room has a number of wrong guesses and then the round is
/// over. A guessed letter tints right or wrong and goes out of play, so the
/// board itself is the record of what has been tried, which is the job the
/// drawn figure used to do.
class HangmanGame extends GridGame {
  const HangmanGame();

  static const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _lives = 6;

  @override
  String get id => 'hangman';

  @override
  String get title => 'Hangman';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.deepTeal);

  @override
  int get cols => 7;

  @override
  int get rows => 4;

  /// The word rides in the FIRST cell's face, out of the alphabet's way —
  /// 26 letters in a 7×4 board leave two spare squares, and one of them is
  /// where the answer lives.
  static String wordOf(GridBoard b) =>
      b.cells.length > 26 ? (b.cells[26].face ?? '') : '';

  @override
  List<BoardCell> deal(ContentSource content) {
    // Charades prompts are single guessable things — the right shape for a
    // word to guess, and already in the bank.
    final picks = content.take(ContentKind.charades, 1);
    final word =
        (picks.isEmpty
                ? 'PLAYGROUND'
                : (picks.first.payload['text']! as String))
            .toUpperCase()
            .replaceAll(RegExp('[^A-Z]'), '');
    return [
      for (final l in _letters.split('')) BoardCell(label: l),
      // Carrier cells: the word, and a pad so the board stays rectangular.
      BoardCell(face: word.isEmpty ? 'PLAYGROUND' : word),
      const BoardCell(state: CellState.done),
    ];
  }

  /// The two carrier squares hold the answer and a pad. They are storage,
  /// not board — and rendering them put the WORD on screen in small type
  /// beside the alphabet, which is the one thing the game is about not doing.
  @override
  BoardCell present(BoardCell c) =>
      c.label == null ? const BoardCell(state: CellState.done) : c;

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    // The carriers are not squares to guess.
    if (i >= 26) return null;
    if (b.cells[i].state != CellState.hidden) return null;
    final letter = b.cells[i].label ?? '';
    final inWord = wordOf(b).contains(letter);
    return b.withAt(
      i,
      b.cells[i].copyWith(
        state: CellState.done,
        tint: inWord ? CellTint.right : CellTint.wrong,
      ),
    );
  }

  int _wrong(GridBoard b) =>
      b.cells.take(26).where((c) => c.tint == CellTint.wrong).length;

  bool _solved(GridBoard b) {
    final got = b.cells
        .take(26)
        .where((c) => c.tint == CellTint.right)
        .map((c) => c.label)
        .toSet();
    final w = wordOf(b);
    return w.isNotEmpty && w.split('').every(got.contains);
  }

  @override
  String? titleFor(GridBoard b) {
    if (_solved(b)) return 'You got it!';
    if (_wrong(b) >= _lives) return 'Out of guesses — it was ${wordOf(b)}';
    return null;
  }

  /// The word, masked. This is the whole reason Hangman fits a grid at all:
  /// the answer is a LINE, and the shape already has one.
  @override
  String? noteFor(GridBoard b) {
    final got = b.cells
        .take(26)
        .where((c) => c.tint == CellTint.right)
        .map((c) => c.label)
        .toSet();
    final over = _solved(b) || _wrong(b) >= _lives;
    final shown = [
      for (final ch in wordOf(b).split(''))
        if (over || got.contains(ch)) ch else '_',
    ].join(' ');
    if (over) return shown;
    return '$shown   ·   ${_lives - _wrong(b)} left';
  }
}
