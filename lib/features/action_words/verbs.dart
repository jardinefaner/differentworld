import 'package:flutter/widgets.dart';

/// One of the 12 permanent action words. The set NEVER changes — kids,
/// worlds, and the whole collection mechanic are built on these exact
/// ids, so adding/removing one would break every stored pick.
@immutable
class Verb {
  const Verb(this.id, this.emoji, this.label, this.lens);

  /// Stable lowercase id stored in `entries.details.verb_picks`.
  final String id;
  final String emoji;
  final String label;

  /// The LENS — how this verb shapes the same activity. The whole system's
  /// personalization engine: one activity, but a kid who picked CARRY does
  /// it carefully while one who picked PLAY makes a game of it
  /// (docs/ACTION_WORDS.md). Kid-facing imperative "how".
  final String lens;
}

/// The canonical 12, in display order (docs/ACTION_WORDS.md).
const List<Verb> kVerbs = [
  Verb('carry', '📦', 'Carry', 'carry it carefully'),
  Verb('listen', '👂', 'Listen', 'listen for what it needs'),
  Verb('play', '🎉', 'Play', 'make a game of it'),
  Verb('spark', '✨', 'Spark', 'start something new'),
  Verb('flow', '🌊', 'Flow', 'find the smooth, fast way'),
  Verb('build', '🧱', 'Build', 'build something that lasts'),
  Verb('watch', '👀', 'Watch', 'watch first, then go'),
  Verb('wait', '⏳', 'Wait', 'pause before each step'),
  Verb('solve', '🧩', 'Solve', 'figure out the tricky part'),
  Verb('help', '💛', 'Help', 'do it together'),
  Verb('echo', '🔁', 'Echo', 'copy what works, then add a twist'),
  Verb('shine', '💡', 'Shine', 'make it your own'),
];

/// Fast id → Verb lookup. Unknown ids return null (forward-compatible with
/// any stray stored value).
final Map<String, Verb> _byId = {for (final v in kVerbs) v.id: v};

Verb? verbById(String id) => _byId[id];

/// Resolve a list of stored verb ids to [Verb]s, dropping any unknowns.
List<Verb> verbsByIds(Iterable<String> ids) =>
    [for (final id in ids) verbById(id)].whereType<Verb>().toList();

/// The number of verbs a kid picks per day.
const int kPicksPerDay = 3;
