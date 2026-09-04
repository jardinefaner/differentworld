// Every route the router backs with a GameDefinition must resolve through
// `gameForRoute`, because that resolver is what decides whether the app
// OFFERS a second screen for an activity.
//
// The failure this pins is silent and one-directional: when the resolver
// misses a game, nothing errors — the cast sheet simply stops offering the TV
// for an activity that would have worked on it. `/activity/starts-with`
// (LetterWordsGame, id `letter-words`) was exactly that: reachable, castable,
// and never offered, because the slug and the id differ by design.
//
// Scanning the router SOURCE rather than the built router is deliberate — the
// question is "does every route a human wired up resolve", and the source is
// where a human wires one up.

import 'dart:io';

import 'package:differentworld/features/games/game_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/app/router.dart').readAsStringSync();

  // A route is "game-backed" when its builder hands a GameDefinition to one of
  // the game shells. That is the router's own statement that the route IS a
  // game, independent of what the slug happens to be called.
  final gameRoutes = RegExp(
    r"path: '(/(?:activity|live|present)/[a-z0-9-]+)',\s*\n"
    r'\s*builder: \([^)]*\) => const (?:GameRunner|LiveGameScreen)\(\s*\n?'
    r'\s*def: (\w+)\(',
  ).allMatches(src).map((m) => (m.group(1)!, m.group(2)!)).toList();

  test('the scan finds the game routes at all', () {
    // Without this the suite passes vacuously the day someone reformats the
    // router and the regex stops matching — a green checker that checks
    // nothing is worse than no checker.
    expect(
      gameRoutes.length,
      greaterThan(15),
      reason:
          'the router-source scan matched almost nothing — the regex has '
          'drifted from how routes are written, so the assertions below are '
          'not actually running',
    );
  });

  test('every game-backed route resolves to a game', () {
    final unresolved = <String>[
      for (final (path, cls) in gameRoutes)
        if (gameForRoute(path) == null) '$path (router says $cls)',
    ];
    expect(
      unresolved,
      isEmpty,
      reason:
          'these routes run a game but gameForRoute says they do not, so '
          'the cast sheet will not offer a second screen for them',
    );
  });

  test('the slug-vs-id mismatch stays covered', () {
    // The one route the naive slug guess gets wrong. Named explicitly so a
    // future rename fails HERE, with an explanation, rather than as a silently
    // missing option in a bottom sheet.
    expect(gameForRoute('/activity/starts-with')?.id, 'letter-words');
  });

  test('a non-game route resolves to nothing', () {
    // The check must be able to say no. Potions is a real brain break that
    // genuinely cannot reach a paired screen; if this ever returns a game the
    // sheet would offer a TV that stays blank.
    expect(gameForRoute('/activity/potions'), isNull);
    expect(gameForRoute('/calm'), isNull);
    expect(gameForRoute('/activity'), isNull);
    expect(gameForRoute('/settings/preferences'), isNull);
  });

  test('query strings and trailing shapes do not defeat it', () {
    expect(gameForRoute('/activity/riddles?from=deck')?.id, 'riddles');
  });
}
