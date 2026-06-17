import 'package:differentworld/features/action_words/conductor.dart';
import 'package:differentworld/features/action_words/world_cast_game.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/as_if_game.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/cues_game.dart';
import 'package:differentworld/features/games/games/fact_or_fib_game.dart';
import 'package:differentworld/features/games/games/grid_reveal_game.dart';
import 'package:differentworld/features/games/games/letter_words_game.dart';
import 'package:differentworld/features/games/games/math_quiz_game.dart';
import 'package:differentworld/features/games/games/memory_match_game.dart';
import 'package:differentworld/features/games/games/name_it_game.dart';
import 'package:differentworld/features/games/games/nownext_game.dart';
import 'package:differentworld/features/games/games/odd_one_out_game.dart';
import 'package:differentworld/features/games/games/picker_game.dart';
import 'package:differentworld/features/games/games/poll_game.dart';
import 'package:differentworld/features/games/games/rhyme_time_game.dart';
import 'package:differentworld/features/games/games/riddles_game.dart';
import 'package:differentworld/features/games/games/story_starters_game.dart';
import 'package:differentworld/features/games/games/this_or_that_game.dart';
import 'package:differentworld/features/games/games/timer_game.dart';
import 'package:differentworld/features/games/games/whats_missing_game.dart';
import 'package:differentworld/features/live_board/board_game.dart';

/// Every host-run game, by id — the single source of truth for resolving a
/// game from a session. This is the keystone for "one place to join"
/// (docs/LIVE_SESSIONS.md): a session advertises its game id, and any joiner
/// resolves it to the right [GameDefinition] here — so the joiner renders the
/// correct `LiveGameScreen` WITHOUT first navigating to that game's route.
///
/// The ids match each game's [GameDefinition.id] and the `/activity/<id>` +
/// `/live/<id>` route segments. Add a new game in ONE place: here.
const List<GameDefinition<dynamic>> liveGames = <GameDefinition<dynamic>>[
  ThisOrThatGame(),
  CharadesGame(),
  RiddlesGame(),
  GridRevealGame(),
  FactOrFibGame(),
  AsIfGame(),
  StoryStartersGame(),
  RhymeTimeGame(),
  LetterWordsGame(),
  MathQuizGame(),
  PollGame(),
  CuesGame(),
  NowNextGame(),
  PickerGame(),
  // Cast-only (seedsFromContentBank=false): hidden from the launcher's
  // content-bank loop, resolved by gameById so the receiver renders it.
  WorldCastGame(),
  ConductorGame(),
  // Deck-seeded card games (docs/CARD_GAMES.md). seedsFromContentBank=false
  // (hidden from the launcher's content-bank loop), but registered so gameById
  // resolves them — the cast receiver + join-by-code + live banner render from
  // the deck seed that rides the wire-state.
  NameItGame(),
  OddOneOutGame(),
  WhatsMissingGame(),
  MemoryMatchGame(),
  // The Live Board — the phone-as-instrument surface (docs/LIVE_BOARD.md).
  // Cast-only: driven by LiveBoardScreen via castStage, rendered by the
  // existing cast receiver.
  BoardGame(),
  // Visual Timer (docs/VISION.md #18) — the foundational "time" primitive, the
  // first castable surface that isn't a game. Cast-only: the cockpit casts it
  // with a default duration; the receiver ticks locally toward the wire's end.
  TimerGame(),
];

/// Resolve a game by its [GameDefinition.id]. Returns null for an id this
/// build doesn't know (e.g. a session announcing a newer game) — callers
/// should degrade gracefully ("That session needs a newer app").
GameDefinition<dynamic>? gameById(String id) {
  for (final game in liveGames) {
    if (game.id == id) return game;
  }
  return null;
}
