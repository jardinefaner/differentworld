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

/// Route segments that do NOT match their game's [GameDefinition.id].
///
/// The registry's contract above says the id matches the `/activity/<id>`
/// segment, and it does — for every game but one. `LetterWordsGame` is
/// `letter-words` and ships at `/activity/starts-with`, because the ROUTE is
/// named for what a staffer calls the activity ("Beat the Letter") while the
/// id is named for the mechanic. Guessing the id from the slug therefore gets
/// exactly one game wrong, silently, and the thing it gets wrong is whether
/// the app offers to put it on a TV.
///
/// `test/unit/game_route_resolution_test.dart` walks the real router and
/// asserts every game-backed route resolves, so a future rename can't
/// reintroduce the gap without failing.
const Map<String, String> _routeSlugOverrides = <String, String>{
  'starts-with': 'letter-words',
};

/// The game a route runs, or null when the route is not a registry game.
///
/// This is the question "can a second screen show this?" — a paired receiver
/// renders `gameById(...)` and nothing else, so a route with no definition
/// here can only ever be MIRRORED from the device it runs on. Offering a
/// second screen for one of those promises a thing the app cannot do.
///
/// Accepts the three shapes a castable surface is reached by:
/// `/activity/<slug>` (host-run), `/live/<slug>` (two-device) and
/// `/present/<slug>` (single-device stage). Anything else returns null.
GameDefinition<dynamic>? gameForRoute(String route) {
  final path = route.split('?').first;
  final parts = path.split('/').where((s) => s.isNotEmpty).toList();
  if (parts.length != 2) return null;
  if (!const {'activity', 'live', 'present'}.contains(parts.first)) return null;
  final slug = parts[1];
  return gameById(_routeSlugOverrides[slug] ?? slug);
}
