import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Lights Out.** Tap a light and its neighbours flip with it. Turn them all
/// off together.
///
/// The whole room can see the board and argue about the next tap, which is
/// what makes a solitaire puzzle work as a group game.
class LightsOutGame extends GridGame {
  const LightsOutGame();

  @override
  String get id => 'lights-out';

  @override
  String get title => 'Lights Out';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.amber);

  @override
  int get cols => 5;

  @override
  int get rows => 5;

  @override
  List<BoardCell> deal(ContentSource content) {
    // Scrambled by PLAYING it backwards from solved, never at random: a random
    // board can be unsolvable, and handing a room an impossible puzzle is a
    // worse outcome than an easy one.
    final r = Random();
    var on = List<bool>.filled(cols * rows, false);
    for (var k = 0; k < 8; k++) {
      on = _flip(on, r.nextInt(cols * rows), cols, rows);
    }
    return [
      for (final lit in on)
        BoardCell(
          state: lit ? CellState.shown : CellState.hidden,
          tint: lit ? CellTint.live : CellTint.none,
        ),
    ];
  }

  static List<bool> _flip(List<bool> on, int i, int cols, int rows) {
    final out = List.of(on);
    final r = i ~/ cols;
    final c = i % cols;
    for (final (dr, dc) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final rr = r + dr;
      final cc = c + dc;
      if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) continue;
      out[rr * cols + cc] = !out[rr * cols + cc];
    }
    return out;
  }

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    final on = [for (final c in b.cells) c.state == CellState.shown];
    final next = _flip(on, i, b.cols, b.rows);
    return [
      for (final lit in next)
        BoardCell(
          state: lit ? CellState.shown : CellState.hidden,
          tint: lit ? CellTint.live : CellTint.none,
        ),
    ];
  }

  @override
  String? titleFor(GridBoard b) =>
      b.count(CellState.shown) == 0 ? 'All out!' : null;

  @override
  String? noteFor(GridBoard b) {
    final n = b.count(CellState.shown);
    return n == 0 ? null : '$n still on';
  }
}
