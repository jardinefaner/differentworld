import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/as_if_game.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/cues_game.dart';
import 'package:differentworld/features/games/games/fact_or_fib_game.dart';
import 'package:differentworld/features/games/games/grid_reveal_game.dart';
import 'package:differentworld/features/games/games/letter_words_game.dart';
import 'package:differentworld/features/games/games/math_quiz_game.dart';
import 'package:differentworld/features/games/games/nownext_game.dart';
import 'package:differentworld/features/games/games/picker_game.dart';
import 'package:differentworld/features/games/games/poll_game.dart';
import 'package:differentworld/features/games/games/rhyme_time_game.dart';
import 'package:differentworld/features/games/games/riddles_game.dart';
import 'package:differentworld/features/games/games/story_starters_game.dart';
import 'package:differentworld/features/games/games/this_or_that_game.dart';

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
