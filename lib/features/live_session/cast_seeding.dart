import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/activity_runtime/content_engine.dart';
import 'package:differentworld/features/games/cards/castable_card_games.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/games/nownext_game.dart';
import 'package:differentworld/features/games/games/nownext_screen.dart';
import 'package:differentworld/features/games/games/picker_game.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `ProviderListenable` is the type both `read`s take; it lives behind
// flutter_riverpod's `misc` entry point rather than its main one.
import 'package:flutter_riverpod/misc.dart';

/// How a cast door reads a provider.
///
/// Both `WidgetRef.read` and `ProviderContainer.read` have exactly this shape,
/// so ONE seeder serves the cockpit, the deck's cast sheet, and a test with no
/// widget tree — which is the point: the thing that decides a game's first
/// round has to be the same thing everywhere, and it has to be checkable.
typedef ReadProvider = StateT Function<StateT>(ProviderListenable<StateT>);

/// How a cast door reaches the app's data — read it, and hold it open.
///
/// Reading alone is not enough, and the second half is not a nicety. An
/// `autoDispose` provider is reaped at the end of the task that touched it, so
/// `read(p.future)` on one loses a race with its own first emission and throws
/// *"disposed during loading state"*. Today's schedule is exactly that shape
/// and nothing in the cockpit watches it, so **casting Now & Next lost that
/// race every time there was a real gap to lose it in** — an unhandled async
/// error and a room looking at the last thing on the screen.
///
/// A `WidgetRef` and a `ProviderContainer` can both do both; they just spell
/// the hold differently (`listenManual` / `listen`), which is why this is a
/// pair passed in rather than a type to implement.
class CastData {
  const CastData({required this.read, required this.hold});

  /// From a widget — the cockpit, the deck's cast sheet.
  factory CastData.ofRef(WidgetRef ref) => CastData(
    read: ref.read,
    hold: (provider) => ref.listenManual(provider, (_, _) {}).close,
  );

  /// From a bare container — a test, with no widget tree in sight.
  factory CastData.ofContainer(ProviderContainer container) => CastData(
    read: container.read,
    hold: (provider) => container.listen(provider, (_, _) {}).close,
  );

  final ReadProvider read;

  /// Keep a provider alive; call the result when you no longer need it.
  final void Function() Function(ProviderListenable<Object?> provider) hold;

  /// Await [future] with [alive] held open for exactly as long as it takes.
  Future<StateT> resolve<StateT>(
    ProviderListenable<Object?> alive,
    ProviderListenable<Future<StateT>> future,
  ) async {
    final release = hold(alive);
    try {
      return await read(future);
    } finally {
      release();
    }
  }
}

/// **What this game's first round looks like** — the one answer, for every
/// door that puts a stage on a room's screen.
///
/// Five doors used to ask this and three knew only half the answer. The deck's
/// long-press ("Send it to a TV"), the cockpit's open-with-a-game, its tune,
/// and its Play again ALL seeded from the content bank alone — so casting Name
/// It, Memory, What's Missing, Guess Who, Spotlight or Now & Next through any
/// of them put an EMPTY stage in front of the room, while the cockpit's own
/// launcher seeded those same games correctly two methods away. Measured on a
/// seeded bank: `name-it → cards=0`, `guess-who → cells=0`, `picker → names=0`,
/// `now-next → blocks=0`, `bingo → 16 placeholder stars`.
///
/// The count was the bug, not any one of them. There are four kinds of seed
/// and this is where they live:
///
/// * **the deck** — the bundled pictures, via the game's OWN [CardSeed] (the
///   same builder its single-device screen uses, so a cast round and a
///   in-hand round are the same round);
/// * **the roster** — Spotlight, from the children actually in the space;
/// * **the schedule** — Now & Next, from today's blocks;
/// * **the content bank** — everything else, honouring the teacher's settings.
///
/// Returns null only for a game that cannot build a round without a choice
/// nobody but the caller can make (which world, which text, which marks) —
/// [GameDefinition.needsCallerSeed]. Those keep their own door, and a caller
/// that gets null should offer that door rather than cast a blank.
Future<Map<String, dynamic>?> castSeedFor(
  CastData data,
  GameDefinition<dynamic> def, {
  Map<String, Object?>? values,
}) async {
  // The deck goes FIRST, and deliberately before the content-bank fallback:
  // three of these games (Bingo, Guess Who, Spot the Difference) also claim
  // `seedsFromContentBank`, and the bank carries no pictures — so asking it
  // yields a board of placeholder stars, or no board at all.
  for (final (card, seed) in castableCardGames) {
    if (card.id == def.id) {
      return seed(
        await data.resolve(pictureDeckProvider, pictureDeckProvider.future),
        values ?? defaultSettingValues(def.settings),
      );
    }
  }
  if (def.id == const PickerGame().id) {
    final subjects = await data.resolve(
      subjectsInSpaceProvider,
      subjectsInSpaceProvider.future,
    );
    return PickerGame.seedFor([for (final s in subjects) s.firstName]);
  }
  if (def.id == const NowNextGame().id) {
    final day = scheduleDayProvider(todayKey());
    return nowNextSeed(await data.resolve(day, day.future));
  }
  if (def.needsCallerSeed) return null;
  final content = ContentEngine(
    data.read(bankedContentProvider).value ?? curatedSeeds,
  );
  return def.initialStateFor(
    content,
    values ?? defaultSettingValues(def.settings),
  );
}
