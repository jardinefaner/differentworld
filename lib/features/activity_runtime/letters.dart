import 'dart:math';

/// Pairs a roster into a **write-to cycle** (docs/VISION.md 2026-06-19): after
/// a shuffle, each person writes to the NEXT in the order and the last writes
/// to the first — so EVERYONE writes exactly one note and receives exactly one,
/// nobody left out. [salt] re-rolls the shuffle deterministically (the
/// "shuffle pairs" button bumps it). Empty for a roster of < 2. Pure + testable.
List<({T from, T to})> letterPairs<T>(List<T> items, int salt) {
  if (items.length < 2) return <({T from, T to})>[];
  final order = List<T>.of(items)..shuffle(Random(salt));
  return [
    for (var i = 0; i < order.length; i++)
      (from: order[i], to: order[(i + 1) % order.length]),
  ];
}
