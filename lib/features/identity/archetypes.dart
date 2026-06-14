/// The 8 staff archetypes — "how do you show up?" (docs/IDENTITY_SYSTEM.md §2).
///
/// Orthogonal to role (authority) and specialty (subject). The WARMEST axis:
/// **self-authored, never assigned by a manager**, and it **decorates, never
/// gates** — the capability is still the gate. Rides the member capabilities
/// JSONB blob (`MemberCaps.archetype`), so storing one needs no schema change.
///
/// The foundation for role-as-home Role-3 (archetype tunes the tool palette):
/// abilities gate, traits flavor. No archetype is lesser; there is no
/// weakness/shadow column.
class Archetype {
  const Archetype({
    required this.id,
    required this.glyph,
    required this.name,
    required this.essence,
    required this.gift,
  });

  /// Stable id stored on the member's caps (lowercase of the name).
  final String id;

  /// The emoji shown on the ID card.
  final String glyph;

  /// Staff-facing name.
  final String name;

  /// First-person essence, rendered verbatim on the card.
  final String essence;

  /// What this temperament gives the group.
  final String gift;
}

/// The catalog (8, per the doc's "we lean 8" call). Order = the doc's table.
const List<Archetype> kArchetypes = <Archetype>[
  Archetype(
    id: 'visionary',
    glyph: '✨',
    name: 'Visionary',
    essence: 'I see what could be, and I get us excited to start.',
    gift: 'direction & momentum',
  ),
  Archetype(
    id: 'doer',
    glyph: '🛠️',
    name: 'Doer',
    essence: 'Give it to me and it gets done.',
    gift: 'things actually ship',
  ),
  Archetype(
    id: 'protector',
    glyph: '🛡️',
    name: 'Protector',
    essence: 'I watch over us — the people and the rules that keep us safe.',
    gift: 'safety & trust',
  ),
  Archetype(
    id: 'anchor',
    glyph: '🌿',
    name: 'Anchor',
    essence: 'When it gets loud, I stay calm and keep us steady.',
    gift: 'stability',
  ),
  Archetype(
    id: 'connector',
    glyph: '💛',
    name: 'Connector',
    essence: "I notice how everyone's doing, and I bring us together.",
    gift: 'belonging',
  ),
  Archetype(
    id: 'sage',
    glyph: '🔍',
    name: 'Sage',
    essence: 'I figure it out — I look closely and find the way through.',
    gift: 'clarity',
  ),
  Archetype(
    id: 'seeker',
    glyph: '🌱',
    name: 'Seeker',
    essence: "I'm curious about everything — I try the new thing first.",
    gift: 'growth & courage',
  ),
  Archetype(
    id: 'beacon',
    glyph: '📣',
    name: 'Beacon',
    essence: 'I see what you did well, and I make sure everyone knows.',
    gift: 'morale & recognition',
  ),
];

/// Resolve an archetype by its stored id; null for unset / unknown.
Archetype? archetypeById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final a in kArchetypes) {
    if (a.id == id) return a;
  }
  return null;
}
