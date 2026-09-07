import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Bingo.** A card of pictures; tap each as it is called. Four in a line
/// wins, and the room shouts it.
///
/// The oldest kind of game in the deck and the cheapest to add — it is a board
/// and one rule, and everything else comes from [GridGame].
class BingoGame extends GridGame {
  const BingoGame();

  @override
  String get id => 'bingo';

  @override
  String get title => 'Bingo';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.amber);

  @override
  int get cols => 4;

  @override
  int get rows => 4;

  @override
  List<BoardCell> deal(ContentSource content) {
    final picks = content.take(ContentKind.picture, cols * rows);
    final cards = [
      for (final p in picks)
        (
          p.payload['image']! as String,
          ((p.payload['label'] as String?) ?? '').trim(),
        ),
    ];
    // A short bank should still fill the card rather than leave holes — a
    // half-empty bingo card reads as broken, not as a short deck.
    while (cards.length < cols * rows) {
      if (cards.isEmpty) {
        cards.add(('★', 'star'));
      } else {
        cards.addAll(List.of(cards));
      }
    }
    cards.shuffle(Random());
    return [
      for (var i = 0; i < cols * rows; i++)
        // The NAME rides in the label. A cell with a face never renders its
        // label, so this is storage — and it is what lets the board call
        // "dog" instead of leaving the room to invent the calls.
        BoardCell(
          face: cards[i].$1,
          label: cards[i].$2,
          state: CellState.shown,
        ),
    ];
  }

  /// Which square has been called. Bingo without a caller is not a game: the
  /// card sat there and whoever tapped four in a row "won", because nothing
  /// ever said what to mark. The board calls now.
  static int calledOf(GridBoard b) => b.tally['call'] ?? -1;

  /// The called square's name, or null when there is nothing outstanding.
  static String? callOf(GridBoard b) {
    final i = calledOf(b);
    if (i < 0 || i >= b.cells.length) return null;
    final name = (b.cells[i].label ?? '').trim();
    return name.isEmpty ? null : name;
  }

  @override
  Map<String, int> get initialTally => {'call': Random().nextInt(cols * rows)};

  /// Draw the next call from the squares still unmarked.
  static int _drawFrom(GridBoard b, {required int justMarked}) {
    final open = [
      for (var i = 0; i < b.cells.length; i++)
        if (i != justMarked && b.cells[i].state != CellState.done) i,
    ];
    if (open.isEmpty) return -1;
    return open[Random().nextInt(open.length)];
  }

  /// Every square starts face-up — you are not uncovering anything, you are
  /// crossing off. So a tap moves shown → done, and a second tap undoes it,
  /// because somebody always mishears a call.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final c = b.cells[i];
    // A second tap undoes it, because somebody always mishears a call.
    final next = c.state == CellState.done ? CellState.shown : CellState.done;
    return b.withAt(i, c.copyWith(state: next));
  }

  /// Marking the called square draws the next call. Marking any other square
  /// is left alone — a room points at the wrong picture all the time, and
  /// punishing that would punish whoever's hand got there first.
  @override
  Map<String, int> tallyAfterPick(GridBoard before, int i) {
    if (i != calledOf(before)) return before.tally;
    if (before.cells[i].state == CellState.done) return before.tally;
    return {...before.tally, 'call': _drawFrom(before, justMarked: i)};
  }

  /// A completed line is the whole game; it just never ended. The line was already computed for the board's title —
  /// it simply never stamped `done`, so the round ran forever.
  @override
  String? outcomeFor(GridBoard b) => titleFor(b);

  @override
  String? titleFor(GridBoard b) {
    if (_hasLine(b)) return 'Bingo!';
    return callOf(b);
  }

  @override
  String? noteFor(GridBoard b) {
    final n = b.count(CellState.done);
    return n == 0 ? null : '$n of ${b.cells.length}';
  }

  /// A line is the win, so the board has to know what one is — rows, columns
  /// and both diagonals.
  bool _hasLine(GridBoard b) {
    bool done(int i) => b.cells[i].state == CellState.done;
    for (var r = 0; r < b.rows; r++) {
      if (List.generate(b.cols, (c) => r * b.cols + c).every(done)) return true;
    }
    for (var c = 0; c < b.cols; c++) {
      if (List.generate(b.rows, (r) => r * b.cols + c).every(done)) return true;
    }
    final n = min(b.cols, b.rows);
    if (List.generate(n, (k) => k * b.cols + k).every(done)) return true;
    if (List.generate(n, (k) => k * b.cols + (b.cols - 1 - k)).every(done)) {
      return true;
    }
    return false;
  }
}
