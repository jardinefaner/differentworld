// Fifty cards, a substitute teacher, and four minutes before the room comes
// back in. The question is never "what is this called" — it is *can I run
// this, right now, with what is in front of me*, and the deck answered
// neither: every card was a title and a tagline, so "Scattergories" and
// "Photo Studio" looked equally runnable when one needs ninety seconds and
// somebody who can type and the other needs a camera.
//
// Every chip is DERIVED from the game. A hand-authored `needs:` field on fifty
// cards is fifty things to keep true, and the first one to go stale teaches a
// teacher to stop believing the rest.

import 'package:differentworld/features/activity_runtime/activity_deck.dart';
import 'package:differentworld/features/activity_runtime/card_signals.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final deck = <DeckCard>[
    ...breakDeck(camera: true),
    ...presentDeck,
  ];

  test('a chip is only ever something the game itself declares', () {
    // The anti-fiction check. Every label has to be traceable to a fact, so
    // this asserts the SHAPE of every label the deriver can emit — a new chip
    // that invents "5-10 min" for forty games fails here rather than shipping
    // as believable signal.
    final allowed = RegExp(
      r'^(camera|pictures|someone types|on a clock|\d+ (teams|rounds)|\d+s)$',
    );
    for (final card in deck) {
      for (final s in signalsFor(card.route)) {
        expect(
          allowed.hasMatch(s.label),
          isTrue,
          reason: '"${s.label}" on ${card.title} is not a derived fact',
        );
      }
    }
  });

  test('the chips agree with the game, card by card', () {
    var teams = 0;
    var types = 0;
    var clocks = 0;
    for (final card in deck) {
      final labels = [for (final s in signalsFor(card.route)) s.label];
      final def = gameForRoute(card.route);
      if (def == null) continue;
      final Object game = def;
      if (game is GridGame && game.alternates) {
        teams++;
        expect(
          labels,
          contains('${game.sides.length} teams'),
          reason: '${card.title} alternates and does not say so',
        );
      }
      if (game is GridGame && game.entryHint != null) types++;
      if (def.ticks) {
        clocks++;
        expect(
          labels.any((l) => l == 'on a clock' || l.endsWith('s')),
          isTrue,
          reason: '${card.title} runs on a clock and does not say so',
        );
      }
    }
    // A chip nothing carries is dead code; a chip everything carries is ink
    // with no information. Both are failures, so pin that the deck really is
    // mixed.
    expect(teams, inInclusiveRange(4, 25), reason: 'teams: $teams of 50');
    expect(clocks, inInclusiveRange(2, 15), reason: 'clocks: $clocks of 50');
    expect(types, greaterThan(0));
  });

  test('a card the app knows nothing about claims nothing', () {
    // Honest silence. Thirteen of the fifty are bespoke screens with no
    // GameDefinition behind them; inventing a chip for those is the trap.
    expect(signalsFor('/activity/not-a-real-route'), isEmpty);
    expect(signalsFor('/settings'), isEmpty);
  });

  test('the camera card says camera — the deck used to just hide it', () {
    expect(
      [for (final s in signalsFor('/activity/photo')) s.label],
      contains('camera'),
    );
  });

  test('no tile is asked to wear more than the two it can draw', () {
    // The tile keeps the front of the list, so the order matters: what you
    // would be STOPPED by has to come before how the round feels.
    for (final card in deck) {
      final labels = [for (final s in signalsFor(card.route)) s.label];
      if (labels.contains('camera')) {
        expect(labels.first, 'camera', reason: '${card.title} buries the need');
      }
    }
  });
}
