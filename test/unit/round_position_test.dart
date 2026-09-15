// How far through the round the room is.
//
// Eight games let a teacher choose the round length and then showed them
// nothing — you pick eight letters, play, and cannot tell whether you are on
// the second or the seventh. It got worse the moment the length became
// tunable, which is the shape of the whole session: a knob without a readout
// is a choice you cannot act on.
//
// It is DERIVED from the wire's `'i'` and `'n'`, so these pin which games get
// a bar and — just as importantly — which correctly get none.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/cards/castable_card_games.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// A FRESH bank per call, never a shared one.
///
/// `LocalContentBank` serves UNSEEN items and tracks "seen" for its lifetime,
/// so one instance shared across tests drains: the first test deals every
/// prompt and the rest get empty rounds. It does not fail — it quietly deals
/// nothing, and a test that asserts on an empty round can pass while
/// exercising nothing at all.
LocalContentBank _bank() => LocalContentBank.seededWith(curatedSeeds);

/// The same rule `_RoundPosition` applies, kept here so a change to one is a
/// visible change to the other.
///
/// Two shapes: most games step an INDEX (`'i'`), As If counts PERFORMANCES
/// (`'p'`) because it crosses two lists rather than walking one.
bool _showsABar(Map<String, dynamic> wire) {
  final of = wire['n'];
  if (of is! num || of < 2) return false;
  final index = wire['i'];
  final performed = wire['p'];
  return (index is num && index >= 0) || (performed is num && performed >= 0);
}

/// The wire a game really starts from — which for a deck-seeded game is NOT
/// `initialState`. Those read the content bank, which carries no pictures, so
/// probing them there measures an empty round rather than the app's
/// (CLAUDE.md — "a game's SEEDED path is the app path").
Map<String, dynamic> _appWire(GameDefinition<dynamic> g) {
  for (final (card, seed) in castableCardGames) {
    if (card.id == g.id) {
      return seed([
        for (var i = 0; i < 40; i++)
          PictureCard(
            id: 'c$i',
            label: 'Card $i',
            image: 'a/$i.png',
            category: ['animal', 'food', 'tool', 'vehicle'][i % 4],
            deck: 'd',
          ),
      ], defaultSettingValues(g.settings));
    }
  }
  return g.initialState(_bank());
}

void main() {
  test('every game with a chosen round length shows where the room is', () {
    final silent = <String>[];
    var checked = 0;
    for (final g in liveGames) {
      if (!g.settings.any((s) => s.id == roundLengthId)) continue;
      checked++;
      if (!_showsABar(_appWire(g))) silent.add(g.id);
    }
    expect(checked, greaterThanOrEqualTo(7), reason: 'lost the round games');
    expect(
      silent,
      isEmpty,
      reason:
          'a teacher can size these rounds and cannot see where they are in '
          'one — the wire needs an int `i` and an `n` above 1: $silent',
    );
  });

  test('the bar fills as the round advances, and lands full on the last', () {
    // An index game, explicitly: As If's bar is measured by the test above,
    // and its maths differ by design.
    final g = liveGames.firstWhere(
      (g) =>
          g.settings.any((s) => s.id == roundLengthId) &&
          _appWire(g)['i'] is num &&
          g.seedsFromContentBank,
    );
    var wire = g.initialStateFor(_bank(), {roundLengthId: 6});
    // NOT six, necessarily: a round is capped by the content the bank has, so
    // the length is read from the wire rather than assumed. Asserting the
    // number I asked for would be testing the bank, not the bar.
    final of = (wire['n'] as num).toDouble();
    expect(of, greaterThan(1), reason: 'the bank had nothing to deal');
    final seen = <double>[];
    for (var i = 0; i < of; i++) {
      final at = (wire['i'] as num).toDouble();
      seen.add(((at + 1) / of).clamp(0.0, 1.0));
      wire = g.reduce(wire, GameIntent.next, const {});
    }
    expect(seen.first, closeTo(1 / of, 0.001), reason: 'the first of $of');
    expect(seen.last, closeTo(1.0, 0.001), reason: 'the last of $of');
    expect(
      seen,
      orderedEquals(List<double>.of(seen)..sort()),
      reason: 'the bar went backwards mid-round',
    );
  });

  test('a game with no fixed length draws nothing', () {
    // The derivation has to fall out for the instruments on its own, or a
    // Spotlight and a Conductor would wear a meaningless bar.
    // `name-it` used to be here and has earned its way out: it publishes a
    // round length now, so a room CAN see how far through the deck it is.
    for (final id in ['picker', 'cues', 'conductor', 'timer']) {
      final g = gameById(id);
      if (g == null) continue;
      expect(
        _showsABar(_appWire(g)),
        isFalse,
        reason: '$id has no round to be partway through',
      );
    }
  });
}
