import 'package:flutter/widgets.dart';

/// One of the 12 permanent action words. The set NEVER changes — kids,
/// worlds, and the whole collection mechanic are built on these exact
/// ids, so adding/removing one would break every stored pick.
@immutable
class Verb {
  const Verb(this.id, this.emoji, this.label);

  /// Stable lowercase id stored in `entries.details.verb_picks`.
  final String id;
  final String emoji;
  final String label;
}

/// The canonical 12, in display order (docs/ACTION_WORDS.md).
const List<Verb> kVerbs = [
  Verb('carry', '📦', 'Carry'),
  Verb('listen', '👂', 'Listen'),
  Verb('play', '🎉', 'Play'),
  Verb('spark', '✨', 'Spark'),
  Verb('flow', '🌊', 'Flow'),
  Verb('build', '🧱', 'Build'),
  Verb('watch', '👀', 'Watch'),
  Verb('wait', '⏳', 'Wait'),
  Verb('solve', '🧩', 'Solve'),
  Verb('help', '💛', 'Help'),
  Verb('echo', '🔁', 'Echo'),
  Verb('shine', '💡', 'Shine'),
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
