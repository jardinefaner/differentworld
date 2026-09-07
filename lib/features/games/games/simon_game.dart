import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Simon.** The board lights a sequence; the room says it back and the host
/// taps it in. One more light each round.
///
/// The sequence rides in the LABELS of the four pads (a digit each), which is
/// how a pure reducer remembers a growing pattern without a new field.
///
/// It did not previously play the sequence BACK. `_pads` lit only the pad you
/// had just tapped, so the room was asked to repeat a pattern it had never
/// been shown — the one thing Simon consists of. The clock now shows it: on
/// deal and after every completed round the board lights each pad in turn,
/// then accepts input.
class SimonGame extends GridGame {
  const SimonGame();

  /// Mistakes allowed. A wrong pad restarts the pattern rather than ending
  /// the game — a room of six-year-olds should keep playing — but three of
  /// them finish the round, so it CAN end and the score means something.
  static const _mistakes = 3;

  @override
  String get id => 'simon';

  @override
  String get title => 'Simon';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.plum);

  @override
  int get cols => 2;

  @override
  int get rows => 2;

  @override
  bool get ticks => true;

  /// Slow enough to say out loud, brisk enough to stay a game.
  @override
  Duration get tickEvery => const Duration(milliseconds: 700);

  /// The pattern so far, read off the pads.
  static List<int> patternOf(GridBoard b) {
    final raw = b.cells.isEmpty ? '' : (b.cells.first.label ?? '');
    return [for (final ch in raw.split('')) int.tryParse(ch) ?? 0];
  }

  /// How far the room has got through it this round.
  static int progressOf(GridBoard b) =>
      b.cells.length < 2 ? 0 : int.tryParse(b.cells[1].label ?? '0') ?? 0;

  /// True while the BOARD is talking. Taps are ignored until it stops.
  static bool showingOf(GridBoard b) => b.score('showAt') >= 0;

  static List<BoardCell> _pads(List<int> pattern, int progress, int lit) => [
    for (var i = 0; i < 4; i++)
      BoardCell(
        // Pad 0 carries the pattern, pad 1 the progress — storage the room
        // never sees, because `present` blanks every label.
        label: i == 0 ? pattern.join() : (i == 1 ? '$progress' : null),
        state: CellState.shown,
        tint: i == lit ? CellTint.live : CellTint.none,
      ),
  ];

  /// Start the board talking: showAt 0 means "about to light the first pad".
  static Map<String, int> _watchFrom(GridBoard b, {int? best, int? wrong}) => {
    ...b.tally,
    'showAt': 0,
    'best': ?best,
    'wrong': ?wrong,
  };

  @override
  List<BoardCell> deal(ContentSource content) =>
      _pads([Random().nextInt(4)], 0, -1);

  @override
  Map<String, int> get initialTally => const {'showAt': 0};

  /// The pads are storage as well as board, so nothing they hold may show.
  @override
  BoardCell present(BoardCell c) => BoardCell(state: c.state, tint: c.tint);

  /// One beat: light the next pad of the pattern, or fall silent and hand
  /// over to the room.
  @override
  List<BoardCell>? onTick(GridBoard b) {
    if (!showingOf(b)) return null;
    final pattern = patternOf(b);
    final at = b.score('showAt');
    if (at >= pattern.length) return _pads(pattern, 0, -1);
    return _pads(pattern, 0, pattern[at]);
  }

  @override
  Map<String, int> tallyAfterTick(GridBoard before) {
    if (!showingOf(before)) return before.tally;
    final at = before.score('showAt');
    // Past the end: stop showing (-1) so taps are accepted again.
    return {
      ...before.tally,
      'showAt': at >= patternOf(before).length ? -1 : at + 1,
    };
  }

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    if (showingOf(b)) return null; // the board is still talking
    final pattern = patternOf(b);
    final at = progressOf(b);
    if (pattern.isEmpty) return null;
    if (i != pattern[at]) {
      // Wrong pad — a fresh, shorter pattern, shown again from the top.
      return _pads([Random().nextInt(4)], 0, -1);
    }
    if (at + 1 < pattern.length) return _pads(pattern, at + 1, i);
    // Round complete: one more light, and the board says the whole thing back.
    return _pads([...pattern, Random().nextInt(4)], 0, -1);
  }

  @override
  Map<String, int> tallyAfterPick(GridBoard before, int i) {
    if (showingOf(before)) return before.tally;
    final pattern = patternOf(before);
    final at = progressOf(before);
    if (pattern.isEmpty) return before.tally;
    if (i != pattern[at]) {
      return _watchFrom(before, wrong: before.score('wrong') + 1);
    }
    if (at + 1 < pattern.length) return before.tally;
    return _watchFrom(before, best: max(before.score('best'), pattern.length));
  }

  @override
  String? outcomeFor(GridBoard b) {
    if (b.score('wrong') < _mistakes) return null;
    final best = b.score('best');
    return best == 0 ? 'Tricky one. Again?' : 'Longest: $best';
  }

  @override
  String? noteFor(GridBoard b) {
    if (showingOf(b)) return 'Watch';
    final n = patternOf(b).length;
    return n <= 1 ? null : '$n';
  }
}
