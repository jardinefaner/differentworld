/// Canonical role-key string constants for the cross-vertical engine
/// keys (NOT the per-vertical labels — those live in `RoleLabels`).
///
/// Use these in any code that needs to know "is THIS row a director?"
/// rather than "is the VIEWER a director?" (the latter goes through
/// `Viewer.isDirector` which respects the cap-or-role parity).
///
/// Adding a role: add the const here, add it to `RoleBundles.rolesFor`
/// in `capability_keys.dart`, and add a label per vertical in
/// `RoleLabels`.
library;

abstract class RoleKey {
  /// Program manager / director role. Default for the inviter of a
  /// new space. Used by the viewer's seeded `isDirector` parity.
  static const String director = 'director';

  /// Lead teacher / group leader. Same caps as teacher + invite +
  /// schedule write.
  static const String leadTeacher = 'lead_teacher';

  /// Counselor / teacher.
  static const String teacher = 'teacher';

  /// Substitute — narrow default bundle (observe + attendance).
  static const String substitute = 'substitute';

  /// Specialist (coach, music teacher, etc.). Per-vertical specialty
  /// field lives on the Member's caps.
  static const String specialist = 'specialist';

  /// Kitchen staff. Childcare-vertical-specific but engine-known.
  static const String kitchen = 'kitchen';

  /// Family-side viewer. Engine-universal; the guardian's
  /// `members.role` is set to this so RLS + UI can route them to the
  /// family lens.
  static const String guardian = 'guardian';
}
