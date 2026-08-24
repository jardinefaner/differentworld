/// Coverage — the report nothing else can produce.
///
/// "Who in this room has still never worked with whom" is the question that
/// makes keeping the history worth it, and it answers something the app was
/// otherwise hiding: at some group sizes covering a room is reachable within a
/// term, and at others it simply is not. Saying so is more honest than
/// promising rotation the arithmetic can't deliver.
library;

import 'dart:math';

import 'package:differentworld/features/rotation/rotation_engine.dart';

class RotationCoverage {
  const RotationCoverage({
    required this.totalPairs,
    required this.metPairs,
    required this.neverMet,
  });

  /// Every pair that could exist among the present roster.
  final int totalPairs;

  /// How many of them have actually happened.
  final int metPairs;

  /// The pairs that have never happened, nearest-first by nothing in
  /// particular — the UI shows a handful and counts the rest.
  final List<(String, String)> neverMet;

  double get fraction => totalPairs == 0 ? 1 : metPairs / totalPairs;

  /// Pairs a single session creates at [groupSize]: each group of g makes
  /// `g*(g-1)/2` pairs, and there are about `n/g` groups.
  static double pairsPerSession(int n, int groupSize) {
    if (n < 2 || groupSize < 2) return 0;
    return n * (groupSize - 1) / 2;
  }

  /// Roughly how many more sessions until everyone has worked with everyone,
  /// at [groupSize]. Null when the arithmetic doesn't terminate (a group size
  /// of one can never cover a room).
  int? sessionsToFinish(int n, int groupSize) {
    final per = pairsPerSession(n, groupSize);
    if (per <= 0) return null;
    return (neverMet.length / per).ceil();
  }

  /// Whole-room cost from scratch — the number that decides whether the
  /// promise is reachable at all. 21 children in pairs is ~20 sessions; in
  /// fours it is ~7.
  static int? sessionsToCoverAll(int n, int groupSize) {
    if (n < 2 || groupSize < 2) return null;
    return ((n - 1) / (groupSize - 1)).ceil();
  }
}

/// Compute coverage for [ids] against [history].
RotationCoverage computeCoverage(List<String> ids, RotationHistory history) {
  final sorted = List<String>.from(ids)..sort();
  final never = <(String, String)>[];
  var met = 0;
  for (var i = 0; i < sorted.length; i++) {
    for (var j = i + 1; j < sorted.length; j++) {
      if (history.haveMet(sorted[i], sorted[j])) {
        met++;
      } else {
        never.add((sorted[i], sorted[j]));
      }
    }
  }
  return RotationCoverage(
    totalPairs: max(0, sorted.length * (sorted.length - 1) ~/ 2),
    metPairs: met,
    neverMet: never,
  );
}
