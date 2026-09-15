import 'dart:math';

import 'package:differentworld/features/games/cards/card_rounds.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/data_seeded_game.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/guess_who_game.dart';
import 'package:differentworld/features/games/games/spot_difference_game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The picture-fed classics. Battleship and Connect Four need no content at
/// all — they are their own board — so they run straight off `GameRunner`;
/// these two draw faces from the bundled deck the same way Memory does.

/// Fill a board with distinct faces, seeded so the phone and every screen
/// derive the same layout.
///
/// **Goes through the GAME for everything except the faces.** This used to
/// build a bare `GridBoard` of images, which skipped two things a game's own
/// `deal` puts on a board: the card's NAME in the label (Bingo's caller reads
/// it — with no label there was nothing to call) and `initialTally` (Bingo's
/// first call and Guess Who's secret both live there — with no tally the
/// caller never existed and the secret was always square zero). Every unit
/// test seeded through `initialState` and passed; every real device seeded
/// through here and shipped a Bingo with no caller. The seed path IS the app
/// path, so it has to produce what the game path produces.
Map<String, dynamic> _boardSeed(
  GridGame game,
  List<PictureCard> cards, {
  required CellState state,
}) {
  final cols = game.cols;
  final rows = game.rows;
  final n = cols * rows;
  if (cards.isEmpty) {
    return GridBoard(cols: cols, rows: rows, cells: const []).toWire();
  }
  final picked = CardRounds.draw(cards, n, cards.length);
  final faces = [for (final c in picked) (c.image, c.label)];
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
      for (var i = 0; i < n; i++)
        BoardCell(face: faces[i].$1, label: faces[i].$2, state: state),
    ],
    tally: game.initialTally,
  ).toWire();
}

/// A bingo CARD is a grid, not a list of rounds — fewer squares is a
/// different board, not a shorter game.
Map<String, dynamic> bingoSeed(
  List<PictureCard> cards, [
  Map<String, Object?> values = const {},
]) => _boardSeed(const BingoGame(), cards, state: CellState.shown);

/// Same: the faces ARE the board. Deal fewer and you have changed the
/// puzzle rather than shortened it.
Map<String, dynamic> guessWhoSeed(
  List<PictureCard> cards, [
  Map<String, Object?> values = const {},
]) => _boardSeed(const GuessWhoGame(), cards, state: CellState.shown);

/// Spot the Difference from the deck. The game's own `deal` reads
/// `ContentKind.picture` from the curated bank, which carries NO pictures —
/// so on a fresh install it dealt an empty board and the room got "No cards
/// yet". Bingo and Guess Who dodged that only because they had this wrapper;
/// this one did not, and was dead on arrival.
/// The odd-one-out grid is the puzzle; its size is a difficulty question,
/// not a round-length one.
Map<String, dynamic> spotDifferenceSeed(
  List<PictureCard> cards, [
  Map<String, Object?> values = const {},
]) {
  const game = SpotDifferenceGame();
  if (cards.isEmpty) {
    return GridBoard(
      cols: game.cols,
      rows: game.rows,
      cells: const [],
    ).toWire();
  }
  const need = SpotDifferenceGame.facesNeeded;
  final picked = CardRounds.draw(cards, need, cards.length);
  final faces = [for (final c in picked) c.image];
  while (faces.length < need) {
    faces.add(faces[faces.length % picked.length]);
  }
  return GridBoard(
    cols: game.cols,
    rows: game.rows,
    cells: SpotDifferenceGame.dealFrom(faces, Random(cards.length)),
    tally: game.initialTally,
  ).toWire();
}

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

/// `/activity/spot-difference` · `/live/spot-difference`
class SpotDifferenceScreen extends ConsumerWidget {
  const SpotDifferenceScreen({required this.live, super.key});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DataSeededGame(
    def: const SpotDifferenceGame(),
    live: live,
    data: ref.watch(pictureDeckProvider),
    seed: spotDifferenceSeed,
  );
}
