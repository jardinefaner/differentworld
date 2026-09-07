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
class SimonGame extends GridGame {
  const SimonGame();

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

  /// The pattern so far, read off the pads.
  static List<int> patternOf(GridBoard b) {
    final raw = b.cells.isEmpty ? '' : (b.cells.first.label ?? '');
    return [for (final ch in raw.split('')) int.tryParse(ch) ?? 0];
  }

  /// How far the room has got through it this round.
  static int progressOf(GridBoard b) =>
      b.cells.length < 2 ? 0 : int.tryParse(b.cells[1].label ?? '0') ?? 0;

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

  @override
  List<BoardCell> deal(ContentSource content) =>
      _pads([Random().nextInt(4)], 0, -1);

  /// The pads are storage as well as board, so nothing they hold may show.
  @override
  BoardCell present(BoardCell c) => BoardCell(state: c.state, tint: c.tint);

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final pattern = patternOf(b);
    final at = progressOf(b);
    if (pattern.isEmpty) return null;
    if (i != pattern[at]) {
      // Wrong pad — start the pattern over rather than ending the game, so a
      // room of six year olds keeps playing.
      return _pads([Random().nextInt(4)], 0, -1);
    }
    if (at + 1 < pattern.length) return _pads(pattern, at + 1, i);
    // Round complete: one more light.
    return _pads([...pattern, Random().nextInt(4)], 0, i);
  }

  @override
  String? noteFor(GridBoard b) {
    final n = patternOf(b).length;
    return n <= 1 ? null : '$n';
  }
}
