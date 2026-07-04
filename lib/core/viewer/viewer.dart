import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/role_keys.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer_override.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who is looking at the app right now.
///
/// The UI never reads `member.role == 'director'` directly — that turns
/// roles into rigid silos. Instead, every conditional reads a typed
/// helper on `Viewer` that resolves to the right capability check.
///
/// A teacher with `canActAsDirector = true` gets the director's lens.
/// A lead teacher with `canInviteStaff = true` can invite. Roles seed
/// capability bundles via `RoleBundles.defaultsFor()`; the bundles
/// are the source of truth.
///
/// Extensible: this currently wraps a Member. When the family /
/// guardian login flow lands (`SpaceCaps.featureFamilyLogin`), add
/// a Guardian-side `Viewer` subclass — same providers, same widgets,
/// new lens.
class Viewer {
  const Viewer({
    required this.member,
    required this.space,
  });

  /// Empty viewer — signed out, or member not yet synced.
  const Viewer.empty() : member = null, space = null;

  final Member? member;
  final Space? space;

  // ---------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------

  bool get isSignedIn => member != null;
  bool get hasSpace => member?.spaceId != null;
  String? get memberId => member?.id;
  String? get spaceId => member?.spaceId;
  String get displayName => member?.displayName ?? '';
  String get roleKey => member?.role ?? '';

  /// Localized label for the role. Routes through the single
  /// [RoleLabels.of] source (consolidated from 5 duplicate
  /// switches per the Council audit).
  String get roleLabel => RoleLabels.of(roleKey);

  /// The member's self-authored archetype id (docs/IDENTITY_SYSTEM.md §2), or
  /// null if unset. Resolve to the catalog entry with `archetypeById` in the
  /// UI layer (core doesn't depend on features). Decorates, never gates.
  String? get archetypeId => memberCaps.getString(MemberCaps.archetype);

  // ---------------------------------------------------------------------
  // Capability accessors
  // ---------------------------------------------------------------------

  Capabilities get memberCaps => member?.caps ?? const Capabilities.empty();

  Capabilities get spaceCaps => space?.caps ?? const Capabilities.empty();

  /// Generic accessor. Prefer the named helpers below for readability.
  bool can(String cap) => memberCaps.getBool(cap);

  // ---------------------------------------------------------------------
  // Member-level abilities (UI gates)
  // ---------------------------------------------------------------------

  // Director-tier abilities fall back to `isDirector` so a director
  // can do basic director things by virtue of being a director — even
  // if their `capabilities` JSONB is missing the field (old member
  // row created before the bundle existed, partial seed, etc.).
  // The principle: don't make a director manually toggle a flag to
  // unlock the work the role implies. Non-directors still need the
  // explicit cap; the role doesn't grant them anything.
  //
  // Cert-gated caps (`canDrive`, `canAdministerMedication`) STAY
  // strict — those require active certifications, regardless of
  // role.

  bool get canObserve =>
      isDirector || memberCaps.getBool(MemberCaps.canObserve);
  bool get canTakeAttendance =>
      isDirector || memberCaps.getBool(MemberCaps.canTakeAttendance);
  bool get canRecordMeal =>
      isDirector || memberCaps.getBool(MemberCaps.canRecordMeal);
  bool get canRecordNap =>
      isDirector || memberCaps.getBool(MemberCaps.canRecordNap);
  bool get canRecordDiaper =>
      isDirector || memberCaps.getBool(MemberCaps.canRecordDiaper);

  // Cert-gated — director role alone is not enough.
  bool get canAdministerMedication =>
      memberCaps.getBool(MemberCaps.canAdministerMedication);
  bool get canDrive => memberCaps.getBool(MemberCaps.canDrive);

  bool get canOpenBuilding =>
      isDirector || memberCaps.getBool(MemberCaps.canOpenBuilding);
  bool get canCloseBuilding =>
      isDirector || memberCaps.getBool(MemberCaps.canCloseBuilding);
  bool get canAuthorizePickup =>
      isDirector || memberCaps.getBool(MemberCaps.canAuthorizePickup);
  bool get canViewBilling =>
      isDirector || memberCaps.getBool(MemberCaps.canViewBilling);
  bool get canInviteStaff =>
      isDirector || memberCaps.getBool(MemberCaps.canInviteStaff);
  bool get canViewAuditLog =>
      isDirector || memberCaps.getBool(MemberCaps.canViewAuditLog);

  /// Can author / edit / delete schedule blocks. Used to hide the
  /// schedule '+' affordance for staff without the cap.
  bool get canManageSchedule =>
      isDirector || memberCaps.getBool(MemberCaps.canManageSchedule);

  /// "Act as director" cap OR actual director role. The cap is the
  /// graceful path; the role is the seeded default.
  bool get isDirector =>
      roleKey == RoleKey.director ||
      memberCaps.getBool(MemberCaps.canActAsDirector);

  /// True for any specialist staff — role + cap parity, like
  /// [isDirector]. The cap is what scheduling / pickup logic checks;
  /// the role is what the director set when inviting. Either route
  /// makes the chrome say "Specialist."
  bool get isSpecialist =>
      roleKey == RoleKey.specialist ||
      memberCaps.getBool(CoreCaps.isSpecialist);

  /// True for substitutes. Substitutes have a narrower default bundle
  /// (observe + attendance, no schedule write, no pickup auth) so
  /// surfaces that distinguish "you're temporary today" read this.
  bool get isSubstitute => roleKey == 'substitute';

  /// The free-text specialty key on `member.capabilities.specialty`,
  /// or null when the role is non-specialist or the director hasn't
  /// chosen one yet. Values come from [SpecialtyKeys]; render through
  /// [specialtyLabel] for the human-readable form.
  String? get specialty {
    final raw = memberCaps.getString(ChildcareCaps.specialty);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// Human-readable specialty for the current viewer. Returns null if
  /// they're not a specialist; "Specialist" (generic) if they're a
  /// specialist with no specialty chosen yet; otherwise the catalog
  /// label (e.g. "Coach", "Reading Specialist").
  String? get specialtyLabel {
    if (!isSpecialist) return null;
    final key = specialty;
    return SpecialtyKeys.labelOf(key);
  }

  /// Can change anyone's role / caps, can revoke invites, can change
  /// program-level toggles. Currently == isDirector but kept as its own
  /// name so screens read intent, not impl.
  bool get canManageSpace => isDirector;

  /// True when this viewer sees every classroom in the space implicitly
  /// (directors), regardless of group_members assignment. Non-directors
  /// are scoped to their assignments.
  bool get seesAllClassrooms => isDirector;

  /// Can edit a specific member (themselves OR a director can edit
  /// anyone). Used to gate the photo-change tap + role editor in
  /// MemberDetailScreen.
  bool canEditMember(Member other) => isDirector || other.id == member?.id;

  /// Can edit the authorized-pickup list for a specific subject.
  /// Default: any staff with [canAuthorizePickup]; guardians of the
  /// subject (overridden in [GuardianViewer]).
  bool canEditPickupFor(String subjectId) => canAuthorizePickup;

  // ---------------------------------------------------------------------
  // Space-level features (per-program toggles)
  // ---------------------------------------------------------------------

  bool feature(String key, {bool fallback = false}) =>
      spaceCaps.getBool(key, fallback: fallback);

  bool get featureObservations =>
      feature(SpaceCaps.featureObservations, fallback: true);
  bool get featureMealLogging =>
      feature(SpaceCaps.featureMealLogging, fallback: true);
  bool get featureNapLogging =>
      feature(SpaceCaps.featureNapLogging, fallback: true);
  bool get featureDiaperLogging => feature(SpaceCaps.featureDiaperLogging);
  bool get featureIncidentReports =>
      feature(SpaceCaps.featureIncidentReports, fallback: true);
  bool get featureMedicationLog => feature(SpaceCaps.featureMedicationLog);
  bool get featureFieldTrips => feature(SpaceCaps.featureFieldTrips);
  bool get featureFamilyLogin => feature(SpaceCaps.featureFamilyLogin);
  bool get featureBilling => feature(SpaceCaps.featureBilling);

  // ---------------------------------------------------------------------
  // Computed lenses (combinations the UI asks about a lot)
  // ---------------------------------------------------------------------

  /// Can this viewer take ANY kind of daily-log action?
  bool get isDailyLogger =>
      canTakeAttendance ||
      canRecordMeal ||
      canRecordNap ||
      canRecordDiaper ||
      canObserve;

  /// Can this viewer see the team management surface? Everyone in a
  /// space can see who's on it; editing is separately gated.
  bool get canSeeTeam => hasSpace;

  /// Should the drawer show Billing? Cap + feature toggle.
  bool get showsBilling => featureBilling && canViewBilling;
}

/// Reactive view of the active viewer.
///
/// Resolution order: if the signed-in auth user matches a [Guardian]
/// row, returns a [GuardianViewer]. Otherwise the staff-side [Viewer]
/// backed by the member row.
///
/// The handle_new_user trigger always creates a members row on first
/// auth; for guardians that row stays alive with `space_id = null` —
/// the viewer falls back to the guardian's space_id via
/// currentSpaceProvider.
final viewerProvider = Provider<Viewer>((ref) {
  final guardian = ref.watch(currentGuardianProvider).value;
  final space = ref.watch(currentSpaceProvider).value;
  if (guardian != null) {
    // childSubjectIds comes from the local `subject_guardians` mirror
    // — the `by_guardian` PowerSync stream keeps it warm. Full
    // `Subject` rows for these IDs are fetched per-screen via
    // `familyChildrenProvider` (PostgREST) in family_providers.dart.
    final ids = ref.watch(myChildSubjectIdsProvider).value ?? const <String>[];
    return GuardianViewer(
      guardian: guardian,
      childSubjectIds: ids,
      space: space,
    );
  }
  final member = ref.watch(currentMemberProvider).value;
  final base = Viewer(member: member, space: space);

  // Wave 168 — dev-only role impersonation. The toggle in the chrome
  // action pill writes to viewerKindOverrideProvider; when set + the
  // real viewer has a member row, swap in a synthetic Viewer with the
  // chosen role's default cap bundle. Gated on kDebugMode so a
  // release build literally can't honor a stale override value.
  if (kDebugMode) {
    final override = ref.watch(viewerKindOverrideProvider);
    if (override != null && override.isNotEmpty) {
      final swapped = buildOverrideViewer(base, override);
      if (swapped != null) return swapped;
    }
  }
  return base;
});

/// Family lens — the viewer subclass for guardian accounts.
///
/// Skeleton in this commit: the class compiles, the data shape is
/// established, but a `guardianViewerProvider` that produces one is
/// future work (requires the family-login auth flow). The class is
/// here so widgets can be written against `Viewer` polymorphically
/// without further refactoring later.
class GuardianViewer extends Viewer {
  const GuardianViewer({
    required this.guardian,
    required this.childSubjectIds,
    required super.space,
  }) : super(member: null);

  final Guardian guardian;

  /// Subject IDs the guardian is allowed to see — derived from
  /// `subject_guardians` rows where `guardian_id == this.guardian.id`.
  /// Every family-side widget filters reads to this set.
  final List<String> childSubjectIds;

  @override
  bool get isSignedIn => true;
  @override
  bool get hasSpace => true;
  @override
  String? get spaceId => guardian.spaceId;
  @override
  String get displayName => guardian.name;
  @override
  String get roleLabel => 'Family';

  // Guardians never have staff caps — staff features hide entirely.
  @override
  bool get isDirector => false;
  @override
  bool get canManageSpace => false;
  @override
  bool get canManageSchedule => false;
  @override
  bool get canInviteStaff => false;
  @override
  bool get canTakeAttendance => false;
  @override
  bool get canObserve => false;
  @override
  bool get isDailyLogger => false;

  /// Per-subject visibility check. Family widgets call this to ensure
  /// they're not rendering data about another family's child.
  bool canSeeSubject(String subjectId) => childSubjectIds.contains(subjectId);

  /// Guardian can edit pickup for their own children.
  @override
  bool canEditPickupFor(String subjectId) => canSeeSubject(subjectId);
}
