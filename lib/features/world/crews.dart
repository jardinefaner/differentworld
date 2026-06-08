import 'package:flutter/widgets.dart';

/// A **crew** — one identity archetype a child picks for the term ("the kind
/// of person I am in this world"). The single *chosen* element of the
/// character sheet, which is otherwise *earned* (the emerging title, the verbs
/// practiced, the worlds visited all derive from what the kid does). A CLOSED
/// catalog (no rarity, no scarcity, fully reachable) per the design council's
/// human-first call — invest in a kid, not a loot box. Stored as the
/// `SubjectCaps.crew` string cap; no migration.
@immutable
class Crew {
  const Crew({
    required this.id,
    required this.emoji,
    required this.name,
    required this.blurb,
  });

  final String id;
  final String emoji;
  final String name;

  /// A one-line "who this is" for the picker — kid-readable, aspirational.
  final String blurb;
}

const List<Crew> kCrews = [
  Crew(id: 'explorer', emoji: '🧭', name: 'Explorer', blurb: 'goes first, finds the way'),
  Crew(id: 'builder', emoji: '🔨', name: 'Builder', blurb: 'makes things that last'),
  Crew(id: 'helper', emoji: '🤝', name: 'Helper', blurb: 'lifts everyone up'),
  Crew(id: 'storyteller', emoji: '📖', name: 'Storyteller', blurb: 'turns the day into a tale'),
  Crew(id: 'maker', emoji: '🎨', name: 'Maker', blurb: 'imagines it, then makes it real'),
  Crew(id: 'scientist', emoji: '🔬', name: 'Scientist', blurb: 'asks why, then finds out'),
  Crew(id: 'guardian', emoji: '🛡️', name: 'Guardian', blurb: 'keeps the room safe and kind'),
  Crew(id: 'dreamer', emoji: '💭', name: 'Dreamer', blurb: 'sees what could be'),
];

Crew? crewById(String? id) {
  if (id == null) return null;
  for (final c in kCrews) {
    if (c.id == id) return c;
  }
  return null;
}
