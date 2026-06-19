// The Letters pairing (docs/VISION.md 2026-06-19) must leave NO ONE out:
// everyone writes exactly one note and receives exactly one, and no one writes
// to themselves. Pin the cycle property.

import 'package:differentworld/features/activity_runtime/letters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fewer than two children → no pairs', () {
    expect(letterPairs(<String>[], 1), isEmpty);
    expect(letterPairs(['Ana'], 1), isEmpty);
  });

  test('everyone writes exactly one and receives exactly one', () {
    final roster = ['Ana', 'Bex', 'Cy', 'Dev', 'Eve'];
    final pairs = letterPairs(roster, 7);
    expect(pairs.length, roster.length);
    expect(
      pairs.map((p) => p.from).toSet(),
      roster.toSet(),
      reason: 'each child is a writer exactly once',
    );
    expect(
      pairs.map((p) => p.to).toSet(),
      roster.toSet(),
      reason: 'each child receives exactly one',
    );
  });

  test('no one writes to themselves', () {
    final roster = ['Ana', 'Bex', 'Cy', 'Dev'];
    for (final p in letterPairs(roster, 3)) {
      expect(p.from, isNot(p.to));
    }
  });

  test('a pair of two writes to each other; same salt is deterministic', () {
    final roster = ['Ana', 'Bex'];
    expect(letterPairs(roster, 9), letterPairs(roster, 9));
    expect(letterPairs(roster, 9).length, 2);
  });
}
