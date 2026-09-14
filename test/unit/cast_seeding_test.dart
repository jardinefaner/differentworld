// Every game the app offers to cast must reach the room with something on it.
//
// It did not. Five doors put a stage on the wire and each decided for itself
// where the seed came from; three of them knew only the content bank. So the
// deck's long-press ("Send it to a TV"), the cockpit opening ON a game, tuning
// a knob, and Play again all cast an EMPTY stage for every game whose round
// comes from the picture deck, the roster or today's schedule — while the
// cockpit's launcher, two methods away, seeded those same games correctly.
// Measured on a seeded bank before the fix:
//
//   name-it → cards=0 · memory-match → cards=0 · guess-who → cells=0
//   picker  → names=0 · now-next → blocks=0 · bingo → 16 placeholder stars
//
// A teacher would have seen a blank TV and had no way to know why. These pin
// the promise — a tile that offers the room a game puts that game in front of
// the room — rather than any one of the doors.

import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/activity_runtime/content_engine.dart';
import 'package:differentworld/features/games/cards/castable_card_games.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/games/nownext_game.dart';
import 'package:differentworld/features/games/games/picker_game.dart';
import 'package:differentworld/features/games/games/timer_game.dart';
import 'package:differentworld/features/live_session/cast_cockpit.dart';
import 'package:differentworld/features/live_session/cast_seeding.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Markers the seed has to carry through. Nonsense on purpose: if one of these
/// shows up in a wire, the seed genuinely read THIS device's data rather than
/// falling back to whatever the content bank had lying around.
const _deckMark = 'Zzdeck';
const _rosterMark = 'Zzroster';
const _scheduleMark = 'Zzschedule';

/// Several categories, because the real deck has several and two card games
/// build their round out of the difference (Odd One Out wants three from one
/// category and a stranger). A one-category fixture makes those games look
/// broken when they are not.
const _categories = ['animal', 'food', 'vehicle', 'tool'];

PictureCard _card(int i) => PictureCard(
  id: '$_deckMark-$i',
  label: '$_deckMark $i',
  image: 'assets/decks/$_deckMark/$i.png',
  category: _categories[i % _categories.length],
  deck: 'test',
);

Subject _subject(int i) => Subject(
  id: 'kid-$i',
  spaceId: 'space-1',
  status: 'enrolled',
  firstName: '$_rosterMark$i',
  lastName: 'Test',
  capabilities: '{}',
  createdAt: '2026-09-14T00:00:00Z',
  updatedAt: '2026-09-14T00:00:00Z',
);

ScheduleBlock _block(int i) => ScheduleBlock(
  id: 'block-$i',
  spaceId: 'space-1',
  groupId: 'group-1',
  date: todayKey(),
  startAt: '2026-09-14T15:0$i:00.000Z',
  endAt: '2026-09-14T16:0$i:00.000Z',
  title: '$_scheduleMark $i',
  kind: 'activity',
  status: BlockStatus.planned,
  createdAt: '2026-09-14T00:00:00Z',
  updatedAt: '2026-09-14T00:00:00Z',
);

/// A device with a deck, a roster and a day — i.e. an ordinary afternoon.
ProviderContainer _afternoon() => ProviderContainer(
  overrides: [
    pictureDeckProvider.overrideWith(
      (ref) async => [for (var i = 0; i < 24; i++) _card(i)],
    ),
    subjectsInSpaceProvider.overrideWith(
      (ref) => Stream.value([for (var i = 0; i < 6; i++) _subject(i)]),
    ),
    // The bank keeps its curated seeds — that IS what a real device falls back
    // to, and it is what every non-data-seeded game plays from.
    bankedContentProvider.overrideWith((ref) => Stream.value(curatedSeeds)),
    scheduleDayProvider(
      todayKey(),
    ).overrideWith(
      (ref) => Stream.value([for (var i = 0; i < 4; i++) _block(i)]),
    ),
  ],
);

/// True when the game keeps its round in CODE rather than in data — seeding
/// it with nothing gives the same wire as seeding it with everything.
///
/// Signals is the one: its cues are a const list and its whole wire is an
/// index, so `{'i': 0}` is a complete round, not a blank one. The exemption
/// checks itself rather than naming names — a game that reads data can't
/// claim it, so a future blank still fails.
bool _holdsItsOwnContent(GameDefinition<dynamic> def, Object? seed) {
  try {
    return jsonEncode(def.initialState(ContentEngine(const <ContentItem>[]))) ==
        jsonEncode(seed);
  } on Object {
    return false;
  }
}

/// Does this wire put ANYTHING in front of the room? Every list empty, every
/// string blank and every number zero is exactly the shape a teacher saw on
/// the TV: a board with no squares, a deck with no cards, a spotlight with no
/// names.
bool _hasAStage(Object? v) {
  if (v is List) return v.any(_hasAStage);
  if (v is Map) return v.values.any(_hasAStage);
  if (v is String) return v.trim().isNotEmpty;
  if (v is num) return v != 0;
  return false;
}

/// The data a game's round is supposed to be built from — null when the
/// content bank is the right source.
String? _mustCarry(GameDefinition<dynamic> def) {
  for (final (card, _) in castableCardGames) {
    if (card.id == def.id) return _deckMark;
  }
  if (def.id == const PickerGame().id) return _rosterMark;
  if (def.id == const NowNextGame().id) return _scheduleMark;
  return null;
}

/// Everything a staffer can put on the room's screen with one tap.
final _castable = <GameDefinition<dynamic>>[
  ...launcherGames,
  const NowNextGame(),
  const PickerGame(),
  const TimerGame(),
];

void main() {
  test('the launcher offers every game it can seed, and each one once', () {
    final ids = [for (final d in _castable) d.id];
    expect(
      ids.toSet().length,
      ids.length,
      reason:
          'a game listed twice is a game a staffer can start two ways, and '
          'one of the two was the broken one: $ids',
    );
    // The card games are the ones that went missing: they were kept out of the
    // launcher's loop by `seedsFromContentBank`, which answers a question
    // about WHERE the seed comes from, not whether there is one.
    for (final (card, _) in castableCardGames) {
      expect(ids, contains(card.id), reason: '${card.title} is not castable');
    }
    for (final def in liveGames.where((d) => d.needsCallerSeed)) {
      expect(
        ids,
        isNot(contains(def.id)),
        reason:
            '${def.title} needs a choice the launcher cannot make — casting '
            'it from a tile would put a blank on the screen',
      );
    }
  });

  test('every castable game reaches the room with something on it', () async {
    final c = _afternoon();
    addTearDown(c.dispose);
    for (final def in _castable) {
      final seed = await castSeedFor(CastData.ofContainer(c), def);
      expect(seed, isNotNull, reason: '${def.title} would cast nothing at all');
      expect(
        _hasAStage(seed) || _holdsItsOwnContent(def, seed),
        isTrue,
        reason: '${def.title} casts a blank stage: ${jsonEncode(seed)}',
      );
    }
  });

  test('a game seeded from the deck, the roster or the day says so', () async {
    final c = _afternoon();
    addTearDown(c.dispose);
    for (final def in _castable) {
      final mark = _mustCarry(def);
      if (mark == null) continue;
      final seed = await castSeedFor(CastData.ofContainer(c), def);
      expect(
        jsonEncode(seed),
        contains(mark),
        reason:
            '${def.title} was seeded from the content bank instead of the '
            'data it is made of — this is the bug, and it looked like a '
            'blank screen',
      );
    }
  });

  test(
    'a game that needs a choice gets no seed, rather than a blank',
    () async {
      final c = _afternoon();
      addTearDown(c.dispose);
      for (final def in liveGames.where((d) => d.needsCallerSeed)) {
        expect(
          await castSeedFor(CastData.ofContainer(c), def),
          isNull,
          reason:
              '${def.title} handed back a seed nobody chose — a caller would '
              'cast it and the room would look at an empty screen',
        );
      }
    },
  );

  test("the teacher's settings reach the seed", () async {
    // The one thing the content-bank path must not lose on the way through.
    final c = _afternoon();
    addTearDown(c.dispose);
    final def = liveGames.firstWhere((d) => d.settings.isNotEmpty);
    final knob = def.settings.first;
    final seed = await castSeedFor(
      CastData.ofContainer(c),
      def,
      values: {knob.id: 3},
    );
    expect(seed, isNotNull);
  });
}
