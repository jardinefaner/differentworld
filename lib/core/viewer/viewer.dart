import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
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
  const Viewer.empty()
      : member = null,
        space = null;

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

  /// Localized label for the role. Default-safe.
  String get roleLabel => switch (roleKey) {
        'director' => 'Director',
        'lead_teacher' => 'Lead teacher',
        'teacher' => 'Teacher',
        'assistant' => 'Assistant',
        _ => 'Signed in',
      };

  // ---------------------------------------------------------------------
  // Capability accessors
  // ---------------------------------------------------------------------

  Capabilities get memberCaps =>
      member?.caps ?? const Capabilities.empty();

  Capabilities get spaceCaps =>
      space?.caps ?? const Capabilities.empty();

  /// Generic accessor. Prefer the named helpers below for readability.
  bool can(String cap) => memberCaps.getBool(cap);

  // ---------------------------------------------------------------------
  // Member-level abilities (UI gates)
  // ---------------------------------------------------------------------

  bool get canObserve => memberCaps.getBool(MemberCaps.canObserve);
  bool get canTakeAttendance =>
      memberCaps.getBool(MemberCaps.canTakeAttendance);
  bool get canRecordMeal => memberCaps.getBool(MemberCaps.canRecordMeal);
  bool get canRecordNap => memberCaps.getBool(MemberCaps.canRecordNap);
  bool get canRecordDiaper => memberCaps.getBool(MemberCaps.canRecordDiaper);
  bool get canAdministerMedication =>
      memberCaps.getBool(MemberCaps.canAdministerMedication);
  bool get canDrive => memberCaps.getBool(MemberCaps.canDrive);
  bool get canOpenBuilding => memberCaps.getBool(MemberCaps.canOpenBuilding);
  bool get canCloseBuilding => memberCaps.getBool(MemberCaps.canCloseBuilding);
  bool get canAuthorizePickup =>
      memberCaps.getBool(MemberCaps.canAuthorizePickup);
  bool get canViewBilling => memberCaps.getBool(MemberCaps.canViewBilling);
  bool get canInviteStaff => memberCaps.getBool(MemberCaps.canInviteStaff);
  bool get canViewAuditLog => memberCaps.getBool(MemberCaps.canViewAuditLog);

  /// "Act as director" cap OR actual director role. The cap is the
  /// graceful path; the role is the seeded default.
  bool get isDirector =>
      roleKey == 'director' || memberCaps.getBool(MemberCaps.canActAsDirector);

  /// Can change anyone's role / caps, can revoke invites, can change
  /// program-level toggles. Currently == isDirector but kept as its own
  /// name so screens read intent, not impl.
  bool get canManageProgram => isDirector;

  /// Can edit a specific member (themselves OR a director can edit
  /// anyone). Used to gate the photo-change tap + role editor in
  /// MemberDetailScreen.
  bool canEditMember(Member other) =>
      isDirector || other.id == member?.id;

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
  bool get featureDiaperLogging =>
      feature(SpaceCaps.featureDiaperLogging);
  bool get featureIncidentReports =>
      feature(SpaceCaps.featureIncidentReports, fallback: true);
  bool get featureMedicationLog =>
      feature(SpaceCaps.featureMedicationLog);
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

/// Reactive view of the active viewer. Recomputes whenever the
/// signed-in member's row or the current space changes.
final viewerProvider = Provider<Viewer>((ref) {
  final member = ref.watch(currentMemberProvider).value;
  final space = ref.watch(currentSpaceProvider).value;
  return Viewer(member: member, space: space);
});
