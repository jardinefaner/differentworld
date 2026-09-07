import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Boggle.** Sixteen letters. Shout every word you can build from them.
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
    return word.isEmpty ? null : word;
  }
}
