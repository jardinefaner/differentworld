import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Boggle.** Sixteen letters. Shout every word you can build from them,
/// before the sand runs out.
///
/// The timer IS Boggle — the real game is three minutes of shouting, and
/// without one this was sixteen letters sitting on a screen with nothing to
/// stop the room. Ninety seconds rather than three minutes: the shape here is
/// a brain break between two other things, not a tournament.
class BoggleGame extends GridGame {
  const BoggleGame();

  /// The real Boggle dice faces, so the board is playable rather than a bag
  /// of random letters — a grid with four Zs in it is not a game. Public
  /// because "every letter came off a die" is the contract worth testing.
  static const dice = [
    'AAEEGN',
    'ELRTTY',
    'AOOTTW',
    'ABBJOO',
    'EHRTVW',
    'CIMOTU',
    'DISTTY',
    'EIOSST',
    'DELRVY',
    'ACHOPS',
    'HIMNQU',
    'EEINSU',
    'EEGHNW',
    'AFFKPS',
    'HLNNRZ',
    'DEILRX',
  ];

  @override
  String get id => 'boggle';

  @override
  String get title => 'Boggle';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.coral);

  /// The sand. Ninety ticks of one second, counted down in the tally.
  static const _seconds = 90;

  @override
  bool get ticks => true;

  @override
  List<BoardCell>? onTick(GridBoard b) => b.cells;

  @override
  Map<String, int> tallyAfterTick(GridBoard before) => before.plus('elapsed');

  @override
  String? outcomeFor(GridBoard b) {
    if (b.score('elapsed') < _seconds) return null;
    final ringed = b.cells.where((c) => c.tint == CellTint.live).length;
    return ringed == 0 ? 'Time! How many did you get?' : 'Time!';
  }

  @override
  int get cols => 4;

  @override
  int get rows => 4;

  @override
  List<BoardCell> deal(ContentSource content) {
    final r = Random();
    final shuffled = List.of(dice)..shuffle(r);
    return [
      for (final die in shuffled)
        BoardCell(
          label: die[r.nextInt(die.length)],
          state: CellState.shown,
        ),
    ];
  }

  /// Ring the letters as you use them, so the room can see the word being
  /// built. Tapping a ringed letter releases it.
  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final c = b.cells[i];
    final on = c.tint == CellTint.live;
    return b.withAt(i, c.copyWith(tint: on ? CellTint.none : CellTint.live));
  }

  @override
  String? noteFor(GridBoard b) {
    final word = [
      for (final c in b.cells)
        if (c.tint == CellTint.live) c.label ?? '',
    ].join();
    final left = _seconds - b.score('elapsed');
    // The clock only appears once it is worth watching. A countdown that
    // starts at 1:30 and sits there is furniture; one that says 0:20 is the
    // game (the half-second rule — live state, read at a glance).
    final clock = left <= 20 ? '${left}s' : null;
    if (word.isEmpty) return clock;
    return clock == null ? word : '$word · $clock';
  }
}
