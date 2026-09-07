import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Whack-a-Mole.** One square pops. Tap it before it moves on.
///
/// The room shouts where it went and one pair of hands does the tapping —
/// which is more fun than it sounds, and the only game here that rewards
/// being quick rather than being right.
///
/// The clock is the game. The first version moved the mole only when you HIT
/// it, so there was no hurry, no miss and no ending — you could stare at one
/// square all afternoon and the score would sit at zero. Now the mole moves on
/// its own every [tickEvery]; a move you didn't catch is a miss, and three
/// misses end the round.
class WhackAMoleGame extends GridGame {
  const WhackAMoleGame();

  static const _mole = '🐹';
  static const _hit = '✨';

  /// Misses allowed before the round ends. Three is enough to feel fair and
  /// few enough that the round stays short — a brain break, not a shift.
  static const _lives = 3;

  @override
  String get id => 'whack-a-mole';

  @override
  String get title => 'Whack-a-Mole';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.amber);

  @override
  int get cols => 3;

  @override
  int get rows => 3;

  @override
  bool get ticks => true;

  /// Brisk enough to feel like a race, slow enough that a room of six-year-
  /// olds can shout "there!" and a hand can reach the screen.
  @override
  Duration get tickEvery => const Duration(milliseconds: 1200);

  @override
  List<BoardCell> deal(ContentSource content) => _withMoleAt(
    Random().nextInt(cols * rows),
    const [],
  );

  List<BoardCell> _withMoleAt(int at, List<BoardCell> _) => [
    for (var i = 0; i < cols * rows; i++)
      if (i == at)
        const BoardCell(face: _mole, state: CellState.shown)
      else
        const BoardCell(),
  ];

  int _moleAt(GridBoard b) => b.cells.indexWhere((c) => c.face == _mole);

  /// Somewhere else — a mole that reappears where it just was reads as a
  /// stuck screen rather than a fast one.
  int _elsewhere(int from) {
    final r = Random();
    var next = r.nextInt(cols * rows);
    if (next == from) next = (next + 1) % (cols * rows);
    return next;
  }

  /// A hit flashes the square and moves the mole on. A tap on an empty square
  /// is simply wrong — it costs nothing, because punishing a miss-tap in a
  /// room where six people are pointing would punish the wrong person.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    if (b.cells[i].face != _mole) return null;
    final next = _elsewhere(i);
    return [
      for (var j = 0; j < b.cells.length; j++)
        if (j == next)
          const BoardCell(face: _mole, state: CellState.shown)
        else if (j == i)
          const BoardCell(face: _hit, state: CellState.done)
        else
          const BoardCell(),
    ];
  }

  @override
  Map<String, int> tallyAfterPick(GridBoard before, int i) =>
      before.cells[i].face == _mole ? before.plus('hit') : before.tally;

  /// The mole got away. That is a miss whether anyone was looking or not —
  /// which is what makes the clock matter.
  @override
  List<BoardCell>? onTick(GridBoard b) => _withMoleAt(
    _elsewhere(_moleAt(b)),
    b.cells,
  );

  @override
  Map<String, int> tallyAfterTick(GridBoard before) => before.plus('miss');

  @override
  String? outcomeFor(GridBoard b) {
    if (b.score('miss') < _lives) return null;
    final hits = b.score('hit');
    if (hits == 0) return 'It got away every time. Again?';
    return '$hits ${hits == 1 ? 'hit' : 'hits'}';
  }

  @override
  String? noteFor(GridBoard b) {
    final hits = b.score('hit');
    final left = _lives - b.score('miss');
    // Both numbers, always, once play has started: a score with no lives
    // beside it doesn't tell you how much game is left.
    if (hits == 0 && left == _lives) return null;
    return '$hits · ${'●' * left.clamp(0, _lives)}';
  }
}
