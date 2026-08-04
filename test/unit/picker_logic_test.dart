// The fair name picker's whole reason to exist, made executable:
// everyone gets picked before anyone repeats — across draws, restarts
// (JSON round-trip), roster changes, and refills.

import 'dart:math';

import 'package:differentworld/features/picker/picker_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final roster = ['a', 'b', 'c', 'd', 'e'];

  group('FairBag', () {
    test('nobody repeats until everyone has been picked', () {
      final rng = Random(7);
      var bag = FairBag.fresh(roster, rng);
      final seen = <String>[];
      for (var i = 0; i < roster.length; i++) {
        final r = bag.draw(1, roster, rng);
        bag = r.bag;
        seen.addAll(r.drawn);
        expect(r.refilled, isFalse);
      }
      expect(seen.toSet(), roster.toSet());
    });

    test('the sixth draw starts a fresh round', () {
      final rng = Random(7);
      var bag = FairBag.fresh(roster, rng);
      for (var i = 0; i < roster.length; i++) {
        bag = bag.draw(1, roster, rng).bag;
      }
      final r = bag.draw(1, roster, rng);
      expect(r.refilled, isTrue);
      expect(r.drawn.length, 1);
      expect(r.bag.picked, r.drawn);
    });

    test('a pair draw across the refill boundary never doubles a kid', () {
      final rng = Random(3);
      var bag = FairBag.fresh(roster, rng);
      // Drain to one remaining.
      bag = bag.draw(4, roster, rng).bag;
      expect(bag.remaining.length, 1);
      final r = bag.draw(2, roster, rng);
      expect(r.refilled, isTrue);
      expect(r.drawn.length, 2);
      expect(r.drawn.toSet().length, 2, reason: 'no kid holds both slots');
    });

    test('JSON round-trip preserves the round', () {
      final rng = Random(1);
      var bag = FairBag.fresh(roster, rng);
      bag = bag.draw(2, roster, rng).bag;
      final revived = FairBag.fromJson(bag.toJson());
      expect(revived.remaining, bag.remaining);
      expect(revived.picked, bag.picked);
    });

    test('roster sync drops the departed and slots in the new', () {
      final rng = Random(5);
      var bag = FairBag.fresh(roster, rng);
      bag = bag.draw(2, roster, rng).bag;
      final departedOne = bag.picked.first;
      final eligible = [
        for (final id in roster)
          if (id != departedOne) id,
        'f',
      ];
      final synced = bag.syncedWith(eligible, rng);
      expect(synced.picked.contains(departedOne), isFalse);
      expect(synced.remaining.contains('f'), isTrue);
      // f is not yet picked; everyone still-present who was picked stays
      // picked (fairness survives the roster change).
      expect(
        {...synced.remaining, ...synced.picked},
        eligible.toSet(),
      );
    });

    test('empty roster draws nothing and never loops', () {
      final rng = Random(2);
      final r = FairBag.fresh(const [], rng).draw(2, const [], rng);
      expect(r.drawn, isEmpty);
    });
  });

  group('splitTeams', () {
    test('even split — sizes differ by at most one, everyone placed', () {
      final rng = Random(9);
      final ids = [for (var i = 0; i < 11; i++) 'k$i'];
      final teams = splitTeams(ids, 3, rng);
      expect(teams.length, 3);
      expect(teams.expand((t) => t).toSet(), ids.toSet());
      final sizes = teams.map((t) => t.length).toList();
      expect(sizes.reduce(max) - sizes.reduce(min), lessThanOrEqualTo(1));
    });

    test('more teams than kids collapses to one per kid', () {
      final rng = Random(9);
      final teams = splitTeams(['a', 'b'], 6, rng);
      expect(teams.length, 2);
      expect(teams.every((t) => t.length == 1), isTrue);
    });
  });
}
