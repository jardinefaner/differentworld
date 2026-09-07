import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Scavenger Hunt.** Things to find outside; tap each one off as it is
/// spotted.
///
/// The one activity in the deck that works when nobody is looking at a
/// screen — the phone goes in a pocket and comes out when somebody shouts.
class ScavengerBingoGame extends GridGame {
  const ScavengerBingoGame();

  /// Findable anywhere a group of children is: a yard, a park, a car park in
  /// the rain. Nothing here needs a season or a particular place.
  static const _things = [
    'Something red',
    'A round thing',
    'Something smooth',
    'A leaf with a hole',
    'Something older than you',
    'A straight line',
    'Something that makes a noise',
    'Two of the same',
    'Something soft',
  ];

  @override
  String get id => 'scavenger';

  @override
  String get title => 'Scavenger Hunt';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.sage);

  @override
  int get cols => 3;

  @override
  int get rows => 3;

  @override
  List<BoardCell> deal(ContentSource content) {
    final things = List.of(_things)..shuffle(Random());
    return [
      for (final t in things.take(9))
        BoardCell(label: t, state: CellState.shown),
    ];
  }

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final c = b.cells[i];
    final found = c.tint == CellTint.right;
    return b.withAt(
      i,
      c.copyWith(
        tint: found ? CellTint.none : CellTint.right,
        state: found ? CellState.shown : CellState.done,
      ),
    );
  }

  @override
  String? titleFor(GridBoard b) =>
      b.cells.every((c) => c.tint == CellTint.right) ? 'All found!' : null;

  @override
  String? noteFor(GridBoard b) {
    final n = b.cells.where((c) => c.tint == CellTint.right).length;
    return n == 0 ? null : '$n of ${b.cells.length}';
  }
}
