import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/memory_match_game.dart';
import 'package:differentworld/features/games/games/memory_match_screen.dart';
import 'package:differentworld/features/games/games/name_it_game.dart';
import 'package:differentworld/features/games/games/name_it_screen.dart';
import 'package:differentworld/features/games/games/odd_one_out_game.dart';
import 'package:differentworld/features/games/games/odd_one_out_screen.dart';
import 'package:differentworld/features/games/games/whats_missing_game.dart';
import 'package:differentworld/features/games/games/whats_missing_screen.dart';

/// Builds a card game's wire-state from the bundled picture deck.
typedef CardSeed = Map<String, dynamic> Function(List<PictureCard> cards);

/// The deck-seeded card games that can be cast from the cockpit, each paired
/// with the seed builder it SHARES with its own present screen — so a cast
/// round and a single-device round are identical, and there's one source of
/// truth per game. The cockpit reads the deck once, runs the seed, and
/// `castStage`s it on the controller's code (docs/CARD_GAMES.md).
///
/// These are `seedsFromContentBank == false`, so they're absent from the
/// launcher's content-bank loop; this list is how they reach the cockpit.
final List<(GameDefinition<dynamic>, CardSeed)> castableCardGames =
    <(GameDefinition<dynamic>, CardSeed)>[
      (const NameItGame(), nameItSeed),
      (const OddOneOutGame(), oddOneOutSeed),
      (const WhatsMissingGame(), whatsMissingSeed),
      (const MemoryMatchGame(), memoryMatchSeed),
    ];
