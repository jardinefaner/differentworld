// Spotlight — the instrument whose entire selling point is fairness.
//
// It used to draw with `Random().nextInt(n)` from inside its control widget,
// avoiding only an immediate repeat: in a room of twelve, one child could go
// three times before another went once. Room tools offered it under the words
// "Fair turns — everyone before anyone repeats" and routed here, so the tool
// that promised fairness was the one without it, while the fair
// implementation (FairBag) sat in a screen a counselor had to leave the
// activity to reach.
//
// These pin the promise instead of the mechanism.

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/picker_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const def = PickerGame();
  const roster = ['Ana', 'Bex', 'Cy', 'Dee'];

  /// Spin [times] and report who was landed on, in order.
  List<String> spin(int times, {List<String> names = roster}) {
    var wire = PickerGame.seedFor(names);
    final landed = <String>[];
    for (var i = 0; i < times; i++) {
      wire = def.reduce(wire, GameIntent.next, const {});
      landed.add(def.decode(wire).current);
    }
    return landed;
  }

  group('everyone before anyone repeats', () {
    test('a full round hands every child exactly one turn', () {
      // Run it many times: a fair draw has to hold on every shuffle, not on
      // the one the test happened to get.
      for (var run = 0; run < 50; run++) {
        final round = spin(roster.length);
        expect(
          round.toSet().length,
          roster.length,
          reason: 'somebody went twice before somebody went once: $round',
        );
        expect(round.toSet(), roster.toSet());
      }
    });

    test('two children with the same name are two children', () {
      // The bag is keyed by INDEX, not by name — a name-keyed bag would treat
      // both Emmas as one child and quietly skip one of them every round.
      const twoEmmas = ['Emma', 'Emma', 'Zoe'];
      for (var run = 0; run < 30; run++) {
        var wire = PickerGame.seedFor(twoEmmas);
        final indices = <int>{};
        for (var i = 0; i < twoEmmas.length; i++) {
          wire = def.reduce(wire, GameIntent.next, const {});
          indices.add(def.decode(wire).index);
        }
        expect(indices.length, 3, reason: 'an Emma was skipped: $indices');
      }
    });

    test('the round that starts over SAYS so', () {
      // A room notices a repeat. A room that is told the round started again
      // stops arguing about it.
      var wire = PickerGame.seedFor(roster);
      for (var i = 0; i < roster.length; i++) {
        wire = def.reduce(wire, GameIntent.next, const {});
        expect(def.decode(wire).fresh, isFalse, reason: 'mid-round $i');
      }
      wire = def.reduce(wire, GameIntent.next, const {});
      expect(def.decode(wire).fresh, isTrue);
    });

    test('the board says how many are still to come', () {
      var wire = PickerGame.seedFor(roster);
      expect(def.decode(wire).left, 4, reason: 'nobody drawn yet');
      wire = def.reduce(wire, GameIntent.next, const {});
      expect(def.decode(wire).left, 3);
    });
  });

  group('the bag rides the wire', () {
    test('a cast screen and the phone read the same round', () {
      // The draw is in the REDUCER, which is the thing both devices run, so
      // the bag has to survive the wire like any other state.
      var wire = PickerGame.seedFor(roster);
      wire = def.reduce(wire, GameIntent.next, const {});
      final asSent = Map<String, dynamic>.from(wire);
      expect(asSent['bag'], isA<String>());
      final there = def.decode(asSent);
      expect(there.current, def.decode(wire).current);
      expect(there.left, def.decode(wire).left);
    });

    test('a state with no bag still draws rather than freezing', () {
      // An older phone, or any seed that predates the bag.
      final legacy = {'names': roster, 'i': 0, 'spun': false};
      final r = def.reduce(legacy, GameIntent.next, const {});
      expect(r['spun'], isTrue);
      expect(def.decode(r).current, isIn(roster));
    });
  });

  group('the edges', () {
    test('an empty roster is a no-op, not a crash', () {
      final empty = {'names': const <String>[], 'i': 0, 'spun': false};
      expect(def.reduce(empty, GameIntent.next, const {})['spun'], isFalse);
    });

    test('reset deals a fresh round', () {
      var wire = PickerGame.seedFor(roster);
      wire = def.reduce(wire, GameIntent.next, const {});
      final after = def.reduce(wire, GameIntent.reset, const {});
      expect(after['spun'], isFalse);
      expect(def.decode(after).left, roster.length);
    });

    test('a spin offers a way to start over; a fresh board does not', () {
      final fresh = def.decode(PickerGame.seedFor(roster));
      expect(def.activeIntents(fresh), {GameIntent.next});
      var wire = PickerGame.seedFor(roster);
      wire = def.reduce(wire, GameIntent.next, const {});
      expect(def.activeIntents(def.decode(wire)), contains(GameIntent.reset));
    });
  });

  testWidgets('Spin lands on someone (full loop, seeded roster)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: GameRunner(
            def: const PickerGame(),
            seed: PickerGame.seedFor(const ['Ana', 'Bex', 'Cy']),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tap Spin'), findsOneWidget); // prompt, pre-spin
    await tester.tap(find.widgetWithText(FilledButton, 'Spin'));
    await tester.pumpAndSettle();

    // GameStage.eyebrow renders tracked-caps (the immersive game-stage style).
    expect(find.text("YOU'RE UP!"), findsOneWidget); // landed
    expect(find.widgetWithText(FilledButton, 'Spin again'), findsOneWidget);
  });
}
