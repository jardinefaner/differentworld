import 'package:flutter/foundation.dart';

/// A named world an action-word combination reveals — an animal, element,
/// or archetype. The reveal is a deterministic LOOKUP (no AI): a kid's 3
/// verbs normalize to a key that maps here.
@immutable
class World {
  const World({
    required this.id,
    required this.emoji,
    required this.name,
    required this.title,
    required this.verbs,
    required this.dinnerQuestion,
  });

  final String id;
  final String emoji;
  final String name;

  /// "The Servant Leader" — the archetype line.
  final String title;

  /// The canonical 3-verb combo (order-independent).
  final Set<String> verbs;

  /// A personalized question for the parent message ("Ask at dinner: …").
  final String dinnerQuestion;
}

/// The named worlds. The first 8 are the brief's canonical set; the rest
/// are obvious starter extras (marked) so the collection isn't empty.
///
/// **The user owns the full ~40.** Append named worlds here — `matchWorld`
/// picks them up automatically. Keep each combo distinct (3 verbs, no
/// repeats); a `debugCheckWorlds()` assertion guards that in debug.
const List<World> kNamedWorlds = [
  // ---- Canonical 8 (from the brief) ----------------------------------
  World(
    id: 'ant',
    emoji: '🐜',
    name: 'Ant',
    title: 'The Servant Leader',
    verbs: {'carry', 'help', 'listen'},
    dinnerQuestion: 'Who did you help carry something for today?',
  ),
  World(
    id: 'dolphin',
    emoji: '🐬',
    name: 'Dolphin',
    title: 'The Joyful Connector',
    verbs: {'play', 'echo', 'flow'},
    dinnerQuestion: 'What game did you play with a friend today?',
  ),
  World(
    id: 'eagle',
    emoji: '🦅',
    name: 'Eagle',
    title: 'The Visionary',
    verbs: {'watch', 'spark', 'shine'},
    dinnerQuestion: 'What did you notice today that nobody else saw?',
  ),
  World(
    id: 'owl',
    emoji: '🦉',
    name: 'Owl',
    title: 'The Wise Observer',
    verbs: {'listen', 'wait', 'watch'},
    dinnerQuestion: 'What did you wait patiently for today?',
  ),
  World(
    id: 'bee',
    emoji: '🐝',
    name: 'Bee',
    title: 'The Maker',
    verbs: {'build', 'solve', 'spark'},
    dinnerQuestion: 'What did you build or figure out today?',
  ),
  World(
    id: 'water',
    emoji: '💧',
    name: 'Water',
    title: 'The Nurturer',
    verbs: {'flow', 'help', 'shine'},
    dinnerQuestion: 'How did you take care of someone today?',
  ),
  World(
    id: 'fire',
    emoji: '🔥',
    name: 'Fire',
    title: 'The Energizer',
    verbs: {'spark', 'shine', 'play'},
    dinnerQuestion: 'What got you really excited today?',
  ),
  World(
    id: 'star',
    emoji: '⭐',
    name: 'Star',
    title: 'The Steady Light',
    verbs: {'shine', 'wait', 'help'},
    dinnerQuestion: 'How were you a good friend today?',
  ),

  // ---- Starter extras (replace / extend freely) ----------------------
  World(
    id: 'beaver',
    emoji: '🦫',
    name: 'Beaver',
    title: 'The Builder',
    verbs: {'build', 'carry', 'flow'},
    dinnerQuestion: 'What did you build today, and how?',
  ),
  World(
    id: 'turtle',
    emoji: '🐢',
    name: 'Turtle',
    title: 'The Patient One',
    verbs: {'wait', 'watch', 'flow'},
    dinnerQuestion: 'What did you take your time with today?',
  ),
  World(
    id: 'dog',
    emoji: '🐶',
    name: 'Dog',
    title: 'The Loyal Friend',
    verbs: {'play', 'help', 'shine'},
    dinnerQuestion: 'Who was your good friend today?',
  ),
  World(
    id: 'fox',
    emoji: '🦊',
    name: 'Fox',
    title: 'The Clever One',
    verbs: {'solve', 'watch', 'wait'},
    dinnerQuestion: 'What tricky problem did you solve today?',
  ),
  World(
    id: 'elephant',
    emoji: '🐘',
    name: 'Elephant',
    title: 'The Rememberer',
    verbs: {'echo', 'listen', 'help'},
    dinnerQuestion: 'What did you remember to do for someone today?',
  ),
  World(
    id: 'wind',
    emoji: '🌪️',
    name: 'Wind',
    title: 'The Free Spirit',
    verbs: {'spark', 'flow', 'play'},
    dinnerQuestion: 'What was the most fun part of today?',
  ),
  World(
    id: 'mountain',
    emoji: '🏔️',
    name: 'Mountain',
    title: 'The Steadfast',
    verbs: {'build', 'wait', 'watch'},
    dinnerQuestion: 'What did you stick with today even when it was hard?',
  ),
];

/// How a kid's combo resolved to a world.
enum WorldMatchKind {
  /// The combo IS a named world's exact 3 verbs.
  exact,

  /// No exact world; this is the named world sharing the most verbs (≥2).
  closest,

  /// Shares fewer than 2 verbs with any named world — a brand-new world
  /// the kid gets to name. [WorldMatch.world] is null.
  fresh,

  /// A world THIS CLASS invented earlier — a once-fresh combo a kid named,
  /// now part of the program's own lookup (continuity). The reveal shows
  /// it by name rather than asking to name it again.
  claimed,
}

@immutable
class WorldMatch {
  const WorldMatch({required this.kind, required this.picks, this.world});

  final WorldMatchKind kind;
  final World? world;

  /// The kid's normalized 3-verb combo.
  final Set<String> picks;

  bool get isNamed => world != null;
}

/// Resolve a 3-verb combo to a world. Order-independent. Deterministic —
/// the reveal is a lookup, not ML (docs/ACTION_WORDS.md).
///
/// - exact named combo → [WorldMatchKind.exact]
/// - else the named world with the most shared verbs, if ≥2 → `closest`
/// - else a fresh world to name → `fresh` (world null)
WorldMatch matchWorld(Set<String> picks) {
  // Exact.
  for (final w in kNamedWorlds) {
    if (setEquals(w.verbs, picks)) {
      return WorldMatch(kind: WorldMatchKind.exact, picks: picks, world: w);
    }
  }
  // Closest by overlap (list order breaks ties deterministically).
  World? best;
  var bestOverlap = 0;
  for (final w in kNamedWorlds) {
    final overlap = picks.intersection(w.verbs).length;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      best = w;
    }
  }
  if (best != null && bestOverlap >= 2) {
    return WorldMatch(kind: WorldMatchKind.closest, picks: picks, world: best);
  }
  // Fresh — a new world to name.
  return WorldMatch(kind: WorldMatchKind.fresh, picks: picks);
}

/// Debug-only invariant: every named world has exactly 3 verbs and a
/// distinct combo. Call from a test (and optionally app boot in debug).
void debugCheckWorlds() {
  assert(() {
    final seen = <String>{};
    for (final w in kNamedWorlds) {
      if (w.verbs.length != 3) {
        throw StateError('World ${w.id} must have exactly 3 verbs');
      }
      final key = (w.verbs.toList()..sort()).join('+');
      if (!seen.add(key)) {
        throw StateError('Duplicate world combo: $key (${w.id})');
      }
    }
    return true;
  }(), 'kNamedWorlds must have 3 distinct verbs and no duplicate combos');
}
