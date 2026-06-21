import 'package:flutter/material.dart';

/// The kinds of THING the app can name and link. Each maps onto a real
/// construct: the universal engine (subject / member / group) plus the
/// content catalogs (activity / location / vehicle / role / world / verb).
/// See docs/VISION.md "every named thing is a live tappable entity".
enum EntityKind {
  subject,
  member,
  group,
  activity,
  location,
  vehicle,
  role,
  world,
  verb,
  tool,
}

/// A reference to one named thing — `kind` + a stable `id` + the `label` as it
/// appeared. The single currency of the tap-anything system: a structured
/// field builds one directly (it already knows the id); the autotagger
/// produces them by matching free text against the on-device index.
@immutable
class EntityRef {
  const EntityRef({required this.kind, required this.id, required this.label});

  final EntityKind kind;

  /// subject / member / group / activity / location / vehicle id; a role's
  /// fingerprint; a world id; a verb id.
  final String id;

  /// Display name as written — what the user sees and tapped.
  final String label;

  /// Identity is (kind, id) — two refs to the same thing are equal even if a
  /// note wrote the label differently ("Sofia" vs "Sofia M.").
  @override
  bool operator ==(Object other) =>
      other is EntityRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  /// Stable de-dupe / exclude key.
  String get key => '${kind.name}:$id';
}

/// Per-kind visual identity. These are CONTENT categories, not theme colors,
/// so the accent is a fixed hue — but the FOREGROUND is derived per brightness
/// ([readableEntityTint]) so a chip stays AA-readable in both light and dark
/// (the content-driven-color contract in CLAUDE.md / THEME_ADHERENCE.md).
extension EntityKindVisual on EntityKind {
  Color get accent => switch (this) {
        EntityKind.subject => const Color(0xFFC8502D), // coral — children
        EntityKind.member => const Color(0xFF3B7DD8), // blue — staff
        EntityKind.group => const Color(0xFF2E8B97), // teal-blue — cohorts
        EntityKind.activity => const Color(0xFF5E9A1F), // green — activities
        EntityKind.location => const Color(0xFF1D9E75), // teal — places
        EntityKind.vehicle => const Color(0xFF6B7280), // slate — vehicles
        EntityKind.role => const Color(0xFFBA7517), // amber — roles
        EntityKind.world => const Color(0xFF6E50D2), // purple — worlds
        EntityKind.verb => const Color(0xFFC23E6B), // rose — action words
        EntityKind.tool => const Color(0xFF5A6BB5), // indigo — tools
      };

  IconData get icon => switch (this) {
        EntityKind.subject => Icons.face_outlined,
        EntityKind.member => Icons.badge_outlined,
        EntityKind.group => Icons.groups_2_outlined,
        EntityKind.activity => Icons.local_activity_outlined,
        EntityKind.location => Icons.place_outlined,
        EntityKind.vehicle => Icons.directions_bus_outlined,
        EntityKind.role => Icons.auto_awesome_outlined,
        EntityKind.world => Icons.travel_explore_outlined,
        EntityKind.verb => Icons.bolt_outlined,
        EntityKind.tool => Icons.handyman_outlined,
      };

  /// The human label for the kind ("Child", "Activity"…) — the peek eyebrow.
  String get noun => switch (this) {
        EntityKind.subject => 'Child',
        EntityKind.member => 'Staff',
        EntityKind.group => 'Cohort',
        EntityKind.activity => 'Activity',
        EntityKind.location => 'Place',
        EntityKind.vehicle => 'Vehicle',
        EntityKind.role => 'Role',
        EntityKind.world => 'World',
        EntityKind.verb => 'Action word',
        EntityKind.tool => 'Tool',
      };

  /// People (→ a `PersonAvatar` with initials) vs a thing (→ [icon]).
  bool get isPerson => this == EntityKind.subject || this == EntityKind.member;
}

/// A foreground tint for [accent] that stays readable on the app surface in
/// either brightness — darken on light, lighten on dark. Used for the chip
/// label + the peek accents. A self-contained HSL nudge so it never depends on
/// an uncertain `AppColors` helper.
Color readableEntityTint(Color accent, Brightness brightness) {
  final hsl = HSLColor.fromColor(accent);
  final l = brightness == Brightness.dark
      ? (hsl.lightness < 0.70 ? 0.74 : hsl.lightness)
      : (hsl.lightness > 0.40 ? 0.36 : hsl.lightness);
  return hsl.withLightness(l).toColor();
}

/// The soft fill behind an entity chip — the accent at low alpha, so it reads
/// as "highlighted / auto-detected" without shouting.
Color entityChipFill(Color accent, Brightness brightness) =>
    accent.withValues(alpha: brightness == Brightness.dark ? 0.24 : 0.14);
