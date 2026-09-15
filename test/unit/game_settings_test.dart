// A declared setting that nothing reads is the `CaptureSpec` trap again: a
// knob in a sheet, a teacher turning it, and a round that ignores them both.
// (CLAUDE.md — "a documented type is not a working feature": grep for a
// CONSUMER, not just a declaration.)
//
// So these check BEHAVIOUR: turning the knob has to change the round, on
// every path that can start one.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/cards/castable_card_games.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/live_session/cast_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// A deck with several categories — Odd One Out builds a round out of the
/// difference, so a one-category deck makes it look broken.
final pictureDeck = [
  for (var i = 0; i < 40; i++)
    PictureCard(
      id: 'c$i',
      label: 'Card $i',
      image: 'a/$i.png',
      category: ['animal', 'food', 'tool', 'vehicle'][i % 4],
      deck: 'd',
    ),
];

void main() {
  LocalContentBank bank() => LocalContentBank.seededWith([
    ...curatedSeeds,
    for (var i = 0; i < 40; i++)
      ContentItem(
        kind: ContentKind.picture,
        fingerprint: 'pic$i',
        payload: {'image': 'assets/decks/pic$i.png', 'label': 'Card $i'},
      ),
  ]);

  List<GameDefinition<dynamic>> tunable() => [
    for (final g in liveGames)
      if (g.settings.isNotEmpty) g,
  ];

  test('enough of the deck is tunable to be worth checking', () {
    // Two of forty-one had any knob at all before 2026-09-14, and the one a
    // substitute actually reaches for — how long is this round — was a
    // hardcoded constant in every game that had one.
    expect(tunable().length, greaterThanOrEqualTo(10));
  });

  test('every declared setting has a sane, reachable default', () {
    for (final g in tunable()) {
      final defaults = defaultSettingValues(g.settings);
      for (final s in g.settings) {
        expect(defaults[s.id], isNotNull, reason: '${g.id}/${s.id}');
        if (s case final IntSetting i) {
          expect(
            i.initial,
            inInclusiveRange(i.min, i.max),
            reason: '${g.id}/${i.id} starts outside its own range',
          );
        }
      }
    }
  });

  /// The wire a game really starts from. A deck-seeded game never passes
  /// through `initialStateFor` — both its doors call its `CardSeed` — so
  /// probing it there measures a path the app does not take, and would report
  /// a working knob as broken (CLAUDE.md — "a game's SEEDED path is the app
  /// path").
  Map<String, dynamic> appWire(
    GameDefinition<dynamic> g,
    Map<String, Object?> values,
  ) {
    for (final (card, seed) in castableCardGames) {
      if (card.id == g.id) return seed(pictureDeck, values);
    }
    return g.initialStateFor(bank(), values);
  }

  test('turning the round-length knob CHANGES the round', () {
    // The decorative-declaration check. A game that lists the setting and
    // then ignores `values` passes every other test in the suite.
    var checked = 0;
    for (final g in tunable()) {
      if (!g.settings.any((s) => s.id == roundLengthId)) continue;
      checked++;
      final defaults = defaultSettingValues(g.settings);
      final short = appWire(g, {...defaults, roundLengthId: 3});
      final long = appWire(g, {...defaults, roundLengthId: 12});
      expect(
        short['n'],
        isNot(long['n']),
        reason: '${g.id} declares a round length and ignores it',
      );
      expect(short['n'], 3, reason: '${g.id} does not honour a short round');
    }
    expect(checked, greaterThanOrEqualTo(10), reason: 'lost the round games');
  });

  test('turning the how-long knob CHANGES the sand', () {
    // Same check for the other shared knob. Both timed classics shipped with
    // a `static const _seconds = 90` nobody could reach: a room of
    // six-year-olds and a room of eleven-year-olds got the same ninety.
    var checked = 0;
    for (final g in tunable()) {
      if (!g.settings.any((s) => s.id == secondsId)) continue;
      checked++;
      final defaults = defaultSettingValues(g.settings);
      final brisk = g.initialStateFor(bank(), {...defaults, secondsId: 45});
      expect(
        ((brisk['k'] as Map?) ?? const {})['secs'],
        45,
        reason: '${g.id} declares a duration and deals its own anyway',
      );
    }
    expect(
      checked,
      greaterThanOrEqualTo(2),
      reason: 'the timed classics lost their clock',
    );
  });

  test('a knob survives Play again, and a counter does not', () {
    // Play again through the PURE reducer (no content, no values — the path a
    // seeded game takes when nothing wires a reseed). The seconds ON the
    // clock are the teacher's choice; the seconds SPENT are the round's.
    for (final g in tunable()) {
      if (!g.settings.any((s) => s.id == secondsId)) continue;
      final defaults = defaultSettingValues(g.settings);
      var wire = g.initialStateFor(bank(), {...defaults, secondsId: 45});
      for (var i = 0; i < 5; i++) {
        wire = g.reduce(wire, GameIntent.tick, const {});
      }
      final spent = ((wire['k'] as Map?) ?? const {})['elapsed'];
      expect(spent, isNot(0), reason: '${g.id} did not count the beats');
      final again = g.reduce(wire, GameIntent.reset, const {});
      final tally = (again['k'] as Map?) ?? const {};
      expect(tally['secs'], 45, reason: '${g.id} lost the chosen duration');
      expect(
        tally['elapsed'] ?? 0,
        0,
        reason: '${g.id} started the new round part-way through the old one',
      );
    }
  });

  test('turning the how-hard knob CHANGES the board', () {
    // Minesweeper's mines, Lights Out's scramble and Hangman's guesses were
    // each a `static const` typed once: the room the game was tuned for got a
    // good round and every other room got that same round. A teacher says
    // "make it easier for the little ones"; they should never be asked to
    // think in mines.
    var checked = 0;
    for (final g in tunable()) {
      if (!g.settings.any((s) => s.id == difficultyId)) continue;
      checked++;
      final defaults = defaultSettingValues(g.settings);
      // Many deals, because a board is dealt at random: two levels CAN land
      // on the same shape once, never fifteen times running.
      var differed = false;
      for (var i = 0; i < 15 && !differed; i++) {
        final gentle = g.initialStateFor(bank(), {
          ...defaults,
          difficultyId: 'gentle',
        });
        final tricky = g.initialStateFor(bank(), {
          ...defaults,
          difficultyId: 'tricky',
        });
        differed = gentle.toString() != tricky.toString();
      }
      expect(
        differed,
        isTrue,
        reason: '${g.id} declares a level and deals the same board anyway',
      );
    }
    expect(checked, greaterThanOrEqualTo(3), reason: 'the classics lost it');
  });

  test('a seed with no settings still works — every other path', () {
    // `initialState` (no values) is what the /live path and every test
    // fixture call. It must produce the game's own defaults, not an empty
    // round.
    for (final g in tunable()) {
      final plain = g.initialState(bank());
      final withDefaults = g.initialStateFor(
        bank(),
        defaultSettingValues(g.settings),
      );
      expect(
        plain['n'],
        withDefaults['n'],
        reason: '${g.id} disagrees with itself about its own default',
      );
    }
  });

  test('CASTING carries the choice — it used to drop it', () {
    // The third seeding path. `CastSession.cast` called `initialState` flat,
    // so a tuned game went to the room at its defaults no matter what.
    for (final g in tunable()) {
      if (!g.settings.any((s) => s.id == roundLengthId)) continue;
      final defaults = defaultSettingValues(g.settings);
      // Through the app's real seed for this game — `castSeedFor` calls the
      // CardSeed for a deck game and `initialStateFor` for the rest, and
      // probing the wrong one here reports a working knob as broken.
      final wire = CastSession.freshWire(
        g.id,
        appWire(g, {...defaults, roundLengthId: 5}),
      );
      expect(
        CastSession.gameStateOf(wire)['n'],
        5,
        reason: '${g.id} is cast at its default however it was tuned',
      );
      expect(CastSession.gameIdOf(wire), g.id);
    }
  });

  test('roundsFrom falls back rather than dealing an empty round', () {
    expect(roundsFrom(const {}, fallback: 8), 8);
    expect(roundsFrom(const {roundLengthId: 0}, fallback: 8), 8);
    expect(roundsFrom(const {roundLengthId: 'six'}, fallback: 8), 8);
    expect(roundsFrom(const {roundLengthId: 4}, fallback: 8), 4);
  });
}
