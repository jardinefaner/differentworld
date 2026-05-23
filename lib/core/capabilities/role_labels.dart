/// Single source of truth for translating a role key to a display
/// label. Replaces five duplicate `_roleLabel` switches that were
/// scattered across the codebase before consolidation (see the
/// Council audit at session-commit-time).
///
/// Per-vertical: a construction `pm` reads "Project manager", a
/// healthcare `np` reads "Nurse practitioner", etc. The default
/// `vertical: 'childcare'` keeps existing call sites working
/// unchanged — they pre-date the multi-vertical work and assume
/// childcare. New code that has the active vertical in scope (via
/// `verticalLabelsProvider`) should thread it through.
///
/// Unknown / unset keys degrade to the "Signed in" default — matches
/// the pre-consolidation behavior of every callsite.
library;

abstract class RoleLabels {
  /// Human label for a role key in a given vertical. Returns
  /// `'Signed in'` for unknown or empty input. The GuardianViewer
  /// subclass overrides `roleLabel` to `'Family'` directly on the
  /// viewer; don't route guardians through this function.
  static String of(String? roleKey, {String vertical = 'childcare'}) {
    if (roleKey == null || roleKey.isEmpty) return 'Signed in';
    if (roleKey == 'guardian') return 'Family';
    return switch (vertical) {
      'construction' => _construction[roleKey] ?? 'Signed in',
      'healthcare' => _healthcare[roleKey] ?? 'Signed in',
      'hospitality' => _hospitality[roleKey] ?? 'Signed in',
      'manufacturing' => _manufacturing[roleKey] ?? 'Signed in',
      _ => _childcare[roleKey] ?? 'Signed in',
    };
  }

  /// Lowercased variant — for places that want sentence-case body
  /// copy: "You signed in as a {director}." Used rarely; prefer
  /// title-case [of] for chips, dropdowns, and member-detail
  /// headers.
  static String lower(String? roleKey, {String vertical = 'childcare'}) =>
      of(roleKey, vertical: vertical).toLowerCase();

  // ---------------------------------------------------------------------------
  // Per-vertical label maps. Keep in sync with `RoleBundles.rolesFor` in
  // capability_keys.dart — same keys, here just with the human labels.
  // ---------------------------------------------------------------------------

  // Afterschool 4-12 vocabulary (Wave 32). Keys stay generic
  // (`director`, `lead_teacher`, `teacher`) for backwards-compat
  // with existing member rows + the engine's vertical-agnostic
  // contract; the LABELS shift to the afterschool lexicon. If you
  // ever support a school-day daycare in the same install, swap
  // these via a settings-level override rather than renaming keys.
  //
  // `assistant` label kept for legacy rows; the role is no longer
  // offered for new members (see `RoleBundles.rolesFor`).
  static const Map<String, String> _childcare = {
    'director': 'Program Manager',
    'lead_teacher': 'Group Leader',
    'teacher': 'Counselor',
    'assistant': 'Aide',
    'substitute': 'Substitute',
    'specialist': 'Specialist',
    'kitchen': 'Kitchen Staff',
  };

  static const Map<String, String> _construction = {
    'pm': 'Project manager',
    'foreman': 'Foreman',
    'journeyman': 'Journeyman',
    'apprentice': 'Apprentice',
    'subcontractor': 'Subcontractor',
  };

  static const Map<String, String> _healthcare = {
    'physician': 'Physician',
    'np': 'Nurse practitioner',
    'rn': 'Registered nurse',
    'tech': 'Technician',
    'admin': 'Administrator',
  };

  static const Map<String, String> _hospitality = {
    'gm': 'General manager',
    'manager': 'Manager',
    'server': 'Server',
    'cook': 'Cook',
    'host': 'Host',
  };

  static const Map<String, String> _manufacturing = {
    'production_manager': 'Production manager',
    'line_lead': 'Line lead',
    'operator': 'Operator',
    'qa': 'QA',
    'maintenance': 'Maintenance',
  };
}
