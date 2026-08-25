/// Fair distribution of the OTHER two scarce things in a room
/// (docs/ROTATION.md).
///
/// Combinations are one scarce resource, and the rotation engine spreads
/// them. Two more get handed out just as unfairly by default:
///
/// - **Attention** — who is asked, who goes first. Uniform-random over a
///   term reliably produces a child who is somehow never picked, because
///   uniform random has no memory. This does.
/// - **Time** — who has spoken, and for how long. A room where the same
///   three children fill every discussion looks fine minute to minute and
///   is obvious over a week, if anything is counting.
///
/// Both read the same `room_events` log the rest of the console writes to,
/// because they ask one question: who has had their share, and how recently.
library;

import 'dart:math';

/// Choose [take] children, favouring whoever has gone longest without.
///
/// Fewest turns first; ties broken at random so the same child does not
/// always lead the queue. Deliberately NOT uniform random — that is the
/// thing this exists to replace.
///
/// [counts] may omit a child entirely; missing means zero, which is exactly
/// the child who should be picked first.
List<String> nextUp({
  required List<String> presentIds,
  required Map<String, int> counts,
  required Random rng,
  int take = 1,
}) {
  if (presentIds.isEmpty || take <= 0) return const [];
  final pool = List<String>.from(presentIds)
    ..shuffle(rng)
    ..sort((a, b) => (counts[a] ?? 0).compareTo(counts[b] ?? 0));
  return pool.take(take.clamp(1, pool.length)).toList();
}

/// How many turns each child has had, from the log.
///
/// Takes ids rather than rows so it stays pure and the caller owns the
/// query — the same shape the rotation engine uses.
Map<String, int> turnCounts(Iterable<String> subjectIdsInOrder) {
  final counts = <String, int>{};
  for (final id in subjectIdsInOrder) {
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
}

/// Seconds spoken per child, summed from talk events.
Map<String, int> talkTotals(Iterable<(String subjectId, int seconds)> events) {
  final totals = <String, int>{};
  for (final (id, secs) in events) {
    totals[id] = (totals[id] ?? 0) + secs;
  }
  return totals;
}

/// The children who have not spoken at all — the point of counting.
///
/// A total of zero and an ABSENT entry mean the same thing here, and both
/// have to be reported: a child with no row is the one most easily missed.
List<String> silent(List<String> presentIds, Map<String, int> totals) => [
  for (final id in presentIds)
    if ((totals[id] ?? 0) <= 0) id,
];

/// Format seconds the way a facilitator reads them mid-room: `0:42`, `3:05`.
String talkClock(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
