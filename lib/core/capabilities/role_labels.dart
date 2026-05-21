/// Single source of truth for translating a role key to a display
/// label. Replaces five duplicate `_roleLabel` switches that were
/// scattered across the codebase before consolidation (see the
/// Council audit at session-commit-time).
///
/// Today the labels are childcare-specific. When the multi-vertical
/// work lands (see `docs/APP_GUIDE.md` Part 2 + vertical-readiness
/// blocker #2), this is the single hook to swap: read the vertical
/// off `Space.capabilities` and return the per-vertical label map
/// from here. Doing it now (with one hook) means the future change
/// is a one-file refactor, not a 5-file grep.
///
/// Roles correspond to `public.member_role` enum values in Postgres
/// (`director`, `lead_teacher`, `teacher`, `assistant`, plus
/// `guardian` from migration 20260519000004). Unknown / unset keys
/// degrade to the "Signed in" default — matches the pre-
/// consolidation behavior of every callsite.
library;

abstract class RoleLabels {
  /// Human label for a role key. Returns `'Signed in'` for unknown
  /// or empty input — every previous _roleLabel switch used the
  /// same fallback. The GuardianViewer subclass overrides
  /// `roleLabel` to `'Family'` directly on the viewer; don't
  /// route guardians through this function.
  static String of(String? roleKey) => switch (roleKey) {
        'director' => 'Director',
        'lead_teacher' => 'Lead teacher',
        'teacher' => 'Teacher',
        'assistant' => 'Assistant',
        'guardian' => 'Family',
        _ => 'Signed in',
      };

  /// Lowercased variant — for places that want sentence-case body
  /// copy: "You signed in as a {director}." Used rarely; prefer
  /// title-case [of] for chips, dropdowns, and member-detail
  /// headers.
  static String lower(String? roleKey) =>
      of(roleKey).toLowerCase();
}
