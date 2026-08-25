// The whole point of these instruments is that they have a memory, so the
// tests are about the memory — not that a random function returns something.

import 'dart:math';

import 'package:differentworld/features/rooms/fair_turns.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final roster = ['a', 'b', 'c', 'd'];

  group('nextUp', () {
    test('picks the child who has gone longest without', () {
      final picked = nextUp(
        presentIds: roster,
        counts: const {'a': 3, 'b': 2, 'c': 1},
        rng: Random(1),
      );
      // d has no entry at all — missing means zero, which is exactly the
      // child most easily forgotten.
      expect(picked, ['d']);
    });

    test('a missing child outranks a child with one turn', () {
      final picked = nextUp(
        presentIds: const ['x', 'y'],
        counts: const {'x': 1},
        rng: Random(2),
      );
      expect(picked, ['y']);
    });

    test('ties are broken at random, not by list order', () {
      // All equal: over many draws every child should lead at least once.
      final leaders = <String>{};
      for (var seed = 0; seed < 40; seed++) {
        leaders.addAll(
          nextUp(presentIds: roster, counts: const {}, rng: Random(seed)),
        );
      }
      expect(
        leaders.length,
        greaterThan(1),
        reason: 'not always the same child',
      );
    });

    test('taking more than the room holds returns the room', () {
      final picked = nextUp(
        presentIds: const ['a', 'b'],
        counts: const {},
        rng: Random(3),
        take: 10,
      );
      expect(picked.length, 2);
      expect(picked.toSet(), {'a', 'b'});
    });

    test('an empty room picks nobody rather than throwing', () {
      expect(
        nextUp(presentIds: const [], counts: const {}, rng: Random(4)),
        isEmpty,
      );
    });
  });

  group('counting', () {
    test('turnCounts tallies a log', () {
      expect(turnCounts(['a', 'b', 'a']), {'a': 2, 'b': 1});
    });

    test('talkTotals sums seconds per child', () {
      expect(
        talkTotals([('a', 30), ('b', 12), ('a', 15)]),
        {'a': 45, 'b': 12},
      );
    });
  });

  group('who has not spoken', () {
    test('counts an absent entry and a zero the same', () {
      expect(silent(['a', 'b', 'c'], const {'a': 40, 'b': 0}), ['b', 'c']);
    });

    test('nobody silent when everyone has spoken', () {
      expect(silent(['a'], const {'a': 5}), isEmpty);
    });
  });

  test('the clock reads the way it is spoken', () {
    expect(talkClock(42), '0:42');
    expect(talkClock(185), '3:05');
    expect(talkClock(0), '0:00');
  });
}
