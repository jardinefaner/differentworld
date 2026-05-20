import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What kind of thing this entry is. Surfaces as a chip on each row
/// AND drives section grouping in the results list.
///
/// Order matters — results are grouped in this enum order so the user
/// sees Actions ahead of Pages ahead of People (roughly: verbs first,
/// then destinations, then nouns).
enum OmniboxCategory {
  action('Action', Icons.bolt_outlined),
  page('Page', Icons.tab_outlined),
  person('Person', Icons.person_outline),
  classroom('Classroom', Icons.meeting_room_outlined),
  place('Location', Icons.place_outlined),
  activity('Activity', Icons.local_activity_outlined),
  vehicle('Vehicle', Icons.directions_bus_outlined),
  setting('Setting', Icons.settings_outlined);

  const OmniboxCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// One indexable entry in the omnibox. Replaces the inline
/// `_Suggestion` class — extends it with:
///
///   - A stable `id` so Recent / Pinned can persist across sessions.
///   - An explicit [category] for section grouping + chip rendering.
///   - Optional [groupId] for per-noun rollups (every entry that
///     relates to kid X gets the same groupId so verb-on-noun
///     composition can surface them together).
///   - Optional [contextTags] for "for you now" boosting (e.g. the
///     morning checklist gets `['morning']`, surfacing 7–9 a.m.).
class OmniboxEntry {
  OmniboxEntry({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    required this.onSelect,
    this.subtitle,
    this.keywords = const <String>[],
    this.groupId,
    this.contextTags = const <String>[],
    this.heroColor,
  });

  /// Stable id — used by Recent + Pinned. Format: `kind:id` so
  /// dynamic entries can include their nouns (e.g. `subject:UUID`,
  /// `vehicle:UUID-checkout`). Static actions just use a hand-chosen
  /// dotted name (`page.today`, `action.capture`).
  final String id;

  final String label;
  final String? subtitle;
  final OmniboxCategory category;
  final IconData icon;
  final List<String> keywords;

  /// Tap target. Pulled the WidgetRef in too so entries can read
  /// other providers (e.g. signOut reads authActionsProvider).
  final void Function(BuildContext, WidgetRef) onSelect;

  /// For per-noun rollups. All entries that act on kid X share the
  /// same `subject:X-uuid` groupId so verb-on-noun composition can
  /// group / dedupe them.
  final String? groupId;

  /// Boost-by-context tags. The "for you now" empty-query band
  /// re-scores entries that match the current context (time of day,
  /// open captures, …).
  final List<String> contextTags;

  /// Optional accent for the leading icon. Used on per-cohort or
  /// per-vehicle rows to carry a tiny color cue.
  final Color? heroColor;

  /// Fuzzy score against a normalized query. Same rough scale as the
  /// old `_Suggestion.score` so the user's mental model stays the
  /// same (exact > prefix > contains > keyword > subtitle).
  int score(String q) {
    final l = label.toLowerCase();
    final s = subtitle?.toLowerCase();
    if (l == q) return 1000;
    if (l.startsWith(q)) return 500;
    if (l.contains(q)) return 250;
    for (final k in keywords) {
      if (k.toLowerCase() == q) return 200;
    }
    if (s != null && s.contains(q)) return 120;
    for (final k in keywords) {
      if (k.toLowerCase().contains(q)) return 80;
    }
    return 0;
  }
}
