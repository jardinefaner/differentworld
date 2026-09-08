import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// One word in a mini crossword.
class _Entry {
  const _Entry(this.word, this.clue, this.row, this.col, {required this.down});
  final String word;
  final String clue;
  final int row;
  final int col;
  final bool down;
}

/// **Crossword.** A small grid, a clue at a time, and the room shouting
/// answers.
///
/// Five by five and five words — a crossword the size of a brain break rather
/// than a Sunday. Tap any square to bring up that word's clue, then type it.
class CrosswordGame extends GridGame {
  const CrosswordGame();

  static const _size = 5;

  /// Hand-built so every crossing actually agrees. A generator would be the
  /// bigger feature; three puzzles is a brain break.
  static const _puzzles = <List<_Entry>>[
    [
      _Entry('CATS', 'Pets that purr', 0, 0, down: false),
      _Entry('APPLE', 'Red or green, keeps doctors away', 2, 0, down: false),
      _Entry('CAP', 'You wear it on your head', 0, 0, down: true),
      _Entry('TOP', 'The opposite of bottom', 0, 3, down: true),
    ],
    [
      _Entry('MOON', 'It comes out at night', 0, 0, down: false),
      _Entry('SNAIL', 'Slow, with a shell', 2, 0, down: false),
      _Entry('MAST', 'The tall pole on a boat', 0, 0, down: true),
      _Entry('NEST', 'Where birds keep eggs', 0, 3, down: true),
    ],
    [
      _Entry('BIRD', 'It has feathers and flies', 0, 0, down: false),
      _Entry('RIVER', 'Water that runs to the sea', 2, 0, down: false),
      _Entry('BAR', 'A straight metal rod', 0, 0, down: true),
      _Entry('DUCK', 'It quacks', 0, 3, down: true),
    ],
  ];

  @override
  String get id => 'crossword';

  @override
  String get title => 'Crossword';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.slate);

  @override
  int get cols => _size;

  @override
  int get rows => _size;

  @override
  String? get entryHint => 'The answer';

  @override
  List<BoardCell> deal(ContentSource content) {
    final which = Random().nextInt(_puzzles.length);
    final puzzle = _puzzles[which];
    // Each square remembers the letter it wants and which clue it belongs to;
    // both are storage, blanked by present() until the word is solved.
    final want = List<String?>.filled(_size * _size, null);
    final owner = List<int?>.filled(_size * _size, null);
    for (var e = 0; e < puzzle.length; e++) {
      final entry = puzzle[e];
      for (var k = 0; k < entry.word.length; k++) {
        final i = entry.down
            ? (entry.row + k) * _size + entry.col
            : entry.row * _size + entry.col + k;
        if (i >= want.length) continue;
        want[i] = entry.word[k];
        owner[i] ??= e;
      }
    }
    return [
      for (var i = 0; i < _size * _size; i++)
        BoardCell(
          // "letter|clueIndex" — one string, because a cell has one label.
          // "letter|clueIndex|puzzleIndex". The puzzle rides on every
          // square because a crossing square belongs to TWO words and only
          // one owner fits — so the clue must be a lookup, not something
          // rebuilt from whichever letters happen to be selected.
          label: want[i] == null ? null : '${want[i]}|${owner[i]}|$which',
          state: want[i] == null ? CellState.done : CellState.hidden,
        ),
    ];
  }

  static String _letter(BoardCell c) => (c.label ?? '').split('|').first;

  /// A solved square shows its letter; an unsolved one shows nothing, and a
  /// blocked one is just dark. The wanted letter must never leak.
  @override
  BoardCell present(BoardCell c) => switch (c.state) {
    CellState.shown => BoardCell(
      label: _letter(c),
      state: CellState.shown,
      tint: c.tint,
    ),
    CellState.done => const BoardCell(state: CellState.done),
    CellState.hidden => BoardCell(tint: c.tint),
  };

  /// Tapping a square selects its word — that is how the clue is asked for.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    if (b.cells[i].label == null) return null;
    final parts = (b.cells[i].label ?? '').split('|');
    if (parts.length < 2) return null;
    final clue = parts[1];
    return [
      for (final c in b.cells)
        c.copyWith(
          tint:
              c.label != null && (c.label ?? '').split('|').elementAt(1) == clue
              ? CellTint.live
              : CellTint.none,
        ),
    ];
  }

  /// Whether [text] solves the word currently selected.
  static bool _solves(GridBoard b, String text) {
    final picked = [
      for (var i = 0; i < b.cells.length; i++)
        if (b.cells[i].tint == CellTint.live) i,
    ];
    if (picked.isEmpty) return false;
    final want = [for (final i in picked) _letter(b.cells[i])].join();
    return text.toUpperCase().replaceAll(RegExp('[^A-Z]'), '') == want;
  }

  /// Right answer, same team goes again; wrong answer passes the clue over.
  /// Teams alternate on MISTAKES, which is what makes it worth conferring
  /// before you answer.
  @override
  bool get alternates => true;

  @override
  bool handsOverAfterEntry(GridBoard before, String text) =>
      !_solves(before, text);

  @override
  String? noteFor(GridBoard b) => turnLine(b);

  /// Type the selected word; every square of it opens at once.
  @override
  List<BoardCell>? onEntry(GridBoard b, String text) {
    final picked = [
      for (var i = 0; i < b.cells.length; i++)
        if (b.cells[i].tint == CellTint.live) i,
    ];
    if (picked.isEmpty) return null;
    if (!_solves(b, text)) {
      // A wrong answer is a MOVE, not a no-op: it clears the selection and
      // hands the clue to the other team. Returning null meant a wrong answer
      // did nothing at all — no feedback, no consequence, no turn.
      return [for (final c in b.cells) c.copyWith(tint: CellTint.none)];
    }
    return [
      for (var i = 0; i < b.cells.length; i++)
        if (picked.contains(i))
          b.cells[i].copyWith(state: CellState.shown, tint: CellTint.none)
        else
          b.cells[i].copyWith(tint: CellTint.none),
    ];
  }

  /// Every square filled. NOT `titleFor`, which also returns the clue for
  /// whichever square is selected — reusing it would end the round the moment
  /// somebody tapped a clue.
  @override
  String? outcomeFor(GridBoard b) =>
      b.cells.any((c) => c.state == CellState.hidden) ? null : 'All done!';

  @override
  String? titleFor(GridBoard b) {
    final open = b.cells.where((c) => c.state == CellState.hidden);
    if (open.isEmpty) return 'All done!';
    // The clue for whatever is selected — asked for by tapping, so it is news
    // rather than a permanent instruction.
    final live = b.cells.where((c) => c.tint == CellTint.live).toList();
    if (live.isEmpty) return null;
    final parts = (live.first.label ?? '').split('|');
    if (parts.length < 3) return null;
    final idx = int.tryParse(parts[1]);
    final which = int.tryParse(parts[2]);
    if (idx == null || which == null) return null;
    if (which >= _puzzles.length || idx >= _puzzles[which].length) return null;
    return _puzzles[which][idx].clue;
  }
}
