import 'dart:math';

import 'package:differentworld/features/games/cards/card_rounds.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/data_seeded_game.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/guess_who_game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The picture-fed classics. Battleship and Connect Four need no content at
/// all — they are their own board — so they run straight off `GameRunner`;
/// these two draw faces from the bundled deck the same way Memory does.

/// Fill a board with distinct faces, seeded so the phone and every screen
/// derive the same layout.
Map<String, dynamic> _boardSeed(
  List<PictureCard> cards, {
  required int cols,
  required int rows,
  required CellState state,
}) {
  final n = cols * rows;
  if (cards.isEmpty) {
    return GridBoard(cols: cols, rows: rows, cells: const []).toWire();
  }
  final picked = CardRounds.draw(cards, n, cards.length);
  final faces = [for (final c in picked) c.image];
  // A short deck still fills the board — a card with holes in it reads as
  // broken rather than as a small deck.
  while (faces.length < n) {
    faces.add(faces[faces.length % picked.length]);
  }
  faces.shuffle(Random(cards.length));
  return GridBoard(
    cols: cols,
    rows: rows,
    cells: [
      for (var i = 0; i < n; i++) BoardCell(face: faces[i], state: state),
    ],
  ).toWire();
}

Map<String, dynamic> bingoSeed(List<PictureCard> cards) =>
    _boardSeed(cards, cols: 4, rows: 4, state: CellState.shown);

Map<String, dynamic> guessWhoSeed(List<PictureCard> cards) =>
    _boardSeed(cards, cols: 4, rows: 3, state: CellState.shown);

/// `/activity/bingo` · `/live/bingo`
class BingoScreen extends ConsumerWidget {
  const BingoScreen({required this.live, super.key});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DataSeededGame(
    def: const BingoGame(),
    live: live,
    data: ref.watch(pictureDeckProvider),
    seed: bingoSeed,
  );
}

/// `/activity/guess-who` · `/live/guess-who`
class GuessWhoScreen extends ConsumerWidget {
  const GuessWhoScreen({required this.live, super.key});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DataSeededGame(
    def: const GuessWhoGame(),
    live: live,
    data: ref.watch(pictureDeckProvider),
    seed: guessWhoSeed,
  );
}
