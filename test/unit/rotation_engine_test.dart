// The rotation engine is the product, so it gets graded, not just exercised:
// one test brute-forces every perfect matching of eight children and asserts
// the greedy construction finds the true optimum.

import 'package:differentworld/features/rotation/rotation_coverage.dart';
import 'package:differentworld/features/rotation/rotation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> roster(int n) => [for (var i = 0; i < n; i++) 'k$i'];

  RotationHistory historyOf(List<(String, String, int)> met) {
    final map = <String, List<int>>{};
    for (final (a, b, r) in met) {
      map.putIfAbsent(pairKey(a, b), () => <int>[]).add(r);
    }
    return RotationHistory(metRounds: map);
  }

  group('planSizes', () {
    test('groups of n, exactly divisible', () {
      expect(
        RotationEngine.planSizes(total: 12, mode: SplitMode.groupsOf, n: 3),
        [3, 3, 3, 3],
      );
    });

    test('absorb spreads the remainder rather than stranding anyone', () {
      // 7 into pairs = 3 pairs + 1 alone. Absorbing gives 3,2,2.
      final sizes = RotationEngine.planSizes(
        total: 7,
        mode: SplitMode.groupsOf,
        n: 2,
      );
      expect(sizes.reduce((a, b) => a + b), 7);
      expect(sizes.every((s) => s >= 2), isTrue, reason: 'nobody stands alone');
    });

    test('ownGroup leaves the remainder as its own smaller group', () {
      expect(
        RotationEngine.planSizes(
          total: 7,
          mode: SplitMode.groupsOf,
          n: 3,
          remainder: RemainderPolicy.ownGroup,
        ),
        [3, 3, 1],
      );
    });

    test('n groups splits as evenly as possible', () {
      expect(
        RotationEngine.planSizes(
          total: 11,
          mode: SplitMode.numberOfGroups,
          n: 3,
        ),
        [4, 4, 3],
      );
    });

    test(
      'a roster smaller than the group size is one group, not a failure',
      () {
        expect(
          RotationEngine.planSizes(total: 3, mode: SplitMode.groupsOf, n: 4),
          [3],
        );
      },
    );
  });

  group('arrange', () {
    test('everyone present is placed exactly once', () {
      final r = const RotationEngine().arrange(
        RotationRequest(
          presentIds: roster(12),
          mode: SplitMode.groupsOf,
          n: 3,
          round: 1,
          seed: 7,
        ),
      );
      final placed = r.groups.expand((g) => g).toList();
      expect(placed.length, 12);
      expect(placed.toSet().length, 12);
      expect(r.groups.length, 4);
    });

    test('the same seed reproduces the same arrangement', () {
      RotationResult run() => const RotationEngine().arrange(
        RotationRequest(
          presentIds: roster(12),
          mode: SplitMode.groupsOf,
          n: 3,
          round: 1,
          seed: 42,
        ),
      );
      expect(run().groups.toString(), run().groups.toString());
    });

    test('it avoids last round’s partners when it can', () {
      // Six children, all of round 1's pairs recorded. Round 2 should be able
      // to give everyone somebody new.
      final history = historyOf([
        ('k0', 'k1', 1),
        ('k2', 'k3', 1),
        ('k4', 'k5', 1),
      ]);
      final r = const RotationEngine().arrange(
        RotationRequest(
          presentIds: roster(6),
          mode: SplitMode.groupsOf,
          n: 2,
          round: 2,
          history: history,
          seed: 3,
        ),
      );
      expect(r.repeatPairs, 0);
      expect(r.newPairs, 3);
    });

    test('keep-apart is never violated when a legal arrangement exists', () {
      final r = const RotationEngine().arrange(
        RotationRequest(
          presentIds: roster(8),
          mode: SplitMode.groupsOf,
          n: 2,
          round: 1,
          keepApart: const [('k0', 'k1'), ('k2', 'k3')],
          seed: 11,
        ),
      );
      for (final g in r.groups) {
        expect(g.contains('k0') && g.contains('k1'), isFalse);
        expect(g.contains('k2') && g.contains('k3'), isFalse);
      }
    });

    test('keep-together travels as one, transitively', () {
      final r = const RotationEngine().arrange(
        RotationRequest(
          presentIds: roster(9),
          mode: SplitMode.groupsOf,
          n: 3,
          round: 1,
          // k0+k1 and k1+k2 means all three share a group.
          keepTogether: const [('k0', 'k1'), ('k1', 'k2')],
          seed: 5,
        ),
      );
      final g = r.groups.firstWhere((g) => g.contains('k0'));
      expect(g, containsAll(<String>['k0', 'k1', 'k2']));
    });

    test('tags spread across groups instead of clumping', () {
      // Four children need support; four groups of two. One each is the only
      // balanced answer.
      final r = const RotationEngine().arrange(
        RotationRequest(
          presentIds: roster(8),
          mode: SplitMode.groupsOf,
          n: 2,
          round: 1,
          tags: const {
            'k0': 'support',
            'k1': 'support',
            'k2': 'support',
            'k3': 'support',
          },
          seed: 9,
        ),
      );
      for (final g in r.groups) {
        final tagged = g.where((id) => int.parse(id.substring(1)) < 4).length;
        expect(tagged, lessThanOrEqualTo(1));
      }
    });

    test('sitting out rotates to whoever has sat out least', () {
      // 7 children into groups of 3 → 6 placed, 1 out. k0 has already sat out
      // twice, so it must not be k0 again.
      final r = const RotationEngine().arrange(
        RotationRequest(
          presentIds: roster(7),
          mode: SplitMode.groupsOf,
          n: 3,
          round: 4,
          remainder: RemainderPolicy.sitOut,
          history: const RotationHistory(satOutCounts: {'k0': 2, 'k1': 1}),
          seed: 2,
        ),
      );
      expect(r.satOut.length, 1);
      expect(r.satOut.first, isNot('k0'));
    });

    test(
      'an impossible constraint degrades to a compromise, not an empty room',
      () {
        // Everyone kept apart from everyone: no legal arrangement exists.
        final everyone = roster(4);
        final apart = <(String, String)>[];
        for (var i = 0; i < everyone.length; i++) {
          for (var j = i + 1; j < everyone.length; j++) {
            apart.add((everyone[i], everyone[j]));
          }
        }
        final r = const RotationEngine().arrange(
          RotationRequest(
            presentIds: everyone,
            mode: SplitMode.groupsOf,
            n: 2,
            round: 1,
            keepApart: apart,
            seed: 1,
          ),
        );
        expect(r.groups.expand((g) => g).length, 4);
      },
    );

    test('one child, or none, never produces a group of one by accident', () {
      final one = const RotationEngine().arrange(
        const RotationRequest(
          presentIds: ['solo'],
          mode: SplitMode.groupsOf,
          n: 2,
          round: 1,
          seed: 1,
        ),
      );
      expect(one.groups.expand((g) => g).toList(), ['solo']);
      final none = const RotationEngine().arrange(
        const RotationRequest(
          presentIds: [],
          mode: SplitMode.groupsOf,
          n: 2,
          round: 1,
          seed: 1,
        ),
      );
      expect(none.groups.expand((g) => g), isEmpty);
    });
  });

  group('history weighting', () {
    test('a repeat costs less the further back it was', () {
      final h = historyOf([('a', 'b', 1)]);
      final soon = h.repeatCost('a', 'b', 2);
      final later = h.repeatCost('a', 'b', 6);
      expect(soon, greaterThan(later));
      expect(later, greaterThan(0), reason: 'it still counts, quietly');
    });

    test('weights halve each round back, so old history cannot swamp new', () {
      final h = historyOf([('a', 'b', 5)]);
      expect(h.repeatCost('a', 'b', 6), closeTo(0.5, 1e-9));
      expect(h.repeatCost('a', 'b', 7), closeTo(0.25, 1e-9));
    });

    test('recording an arrangement folds it back in', () {
      const engine = RotationEngine();
      final r = engine.arrange(
        RotationRequest(
          presentIds: roster(4),
          mode: SplitMode.groupsOf,
          n: 2,
          round: 1,
          seed: 8,
        ),
      );
      final h = const RotationHistory().recording(r, 1);
      for (final g in r.groups) {
        expect(h.haveMet(g[0], g[1]), isTrue);
        expect(h.lastMet(g[0], g[1]), 1);
      }
    });
  });

  group('graded against brute force', () {
    test('greedy finds the optimum over all 105 matchings of eight', () {
      // Eight children into pairs. Give every pair a distinct, known history
      // cost, brute-force all perfect matchings, and require the engine to
      // hit the true minimum — the difference between "it runs" and "it works".
      final ids = roster(8);
      final met = <(String, String, int)>[];
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          // Everything met in round 1 except k0+k1 and k6+k7, the two free pairs.
          final free = (i == 0 && j == 1) || (i == 6 && j == 7);
          if (!free) met.add((ids[i], ids[j], 1));
        }
      }
      final history = historyOf(met);

      double costOf(List<List<String>> pairs) {
        var total = 0.0;
        for (final p in pairs) {
          total += history.repeatCost(p[0], p[1], 2);
        }
        return total;
      }

      // Enumerate every perfect matching (7*5*3*1 = 105).
      var best = double.infinity;
      void walk(List<String> remaining, List<List<String>> acc) {
        if (remaining.isEmpty) {
          best = best < costOf(acc) ? best : costOf(acc);
          return;
        }
        final first = remaining.first;
        for (var i = 1; i < remaining.length; i++) {
          walk(
            [...remaining.sublist(1)]..remove(remaining[i]),
            [
              ...acc,
              [first, remaining[i]],
            ],
          );
        }
      }

      walk(ids, const []);

      final r = const RotationEngine().arrange(
        RotationRequest(
          presentIds: ids,
          mode: SplitMode.groupsOf,
          n: 2,
          round: 2,
          history: history,
          seed: 17,
        ),
      );
      expect(costOf(r.groups), closeTo(best, 1e-9));
    });
  });

  group('coverage', () {
    test('counts what has and has not happened', () {
      final c = computeCoverage(
        roster(4),
        historyOf([('k0', 'k1', 1), ('k2', 'k3', 1)]),
      );
      expect(c.totalPairs, 6);
      expect(c.metPairs, 2);
      expect(c.neverMet.length, 4);
      expect(c.fraction, closeTo(2 / 6, 1e-9));
    });

    test('the arithmetic that decides whether the promise is reachable', () {
      // The number that changes the answer: 21 children take ~20 sessions in
      // pairs and ~7 in fours.
      expect(RotationCoverage.sessionsToCoverAll(21, 2), 20);
      expect(RotationCoverage.sessionsToCoverAll(21, 4), 7);
      expect(RotationCoverage.sessionsToCoverAll(21, 1), isNull);
    });

    test('a fully-covered room reports finished', () {
      final met = <(String, String, int)>[];
      final ids = roster(4);
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          met.add((ids[i], ids[j], 1));
        }
      }
      final c = computeCoverage(ids, historyOf(met));
      expect(c.neverMet, isEmpty);
      expect(c.fraction, 1);
      expect(c.sessionsToFinish(4, 2), 0);
    });
  });
}
