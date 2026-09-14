// A declared setting that nothing reads is the `CaptureSpec` trap again: a
// knob in a sheet, a teacher turning it, and a round that ignores them both.
// (CLAUDE.md — "a documented type is not a working feature": grep for a
// CONSUMER, not just a declaration.)
//
// So these check BEHAVIOUR: turning the knob has to change the round, on
// every path that can start one.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/live_session/cast_session.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('turning the round-length knob CHANGES the round', () {
    // The decorative-declaration check. A game that lists the setting and
    // then ignores `values` passes every other test in the suite.
    for (final g in tunable()) {
      if (!g.settings.any((s) => s.id == roundLengthId)) continue;
      final defaults = defaultSettingValues(g.settings);
      final short = g.initialStateFor(bank(), {...defaults, roundLengthId: 3});
      final long = g.initialStateFor(bank(), {...defaults, roundLengthId: 12});
      expect(
        short['n'],
        isNot(long['n']),
        reason: '${g.id} declares a round length and ignores it',
      );
      expect(short['n'], 3, reason: '${g.id} does not honour a short round');
    }
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
      final wire = CastSession.freshWire(
        g.id,
        g.initialStateFor(bank(), {...defaults, roundLengthId: 5}),
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
