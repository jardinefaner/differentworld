/// String constants for every capability key. Use these instead of
/// raw strings everywhere so the analyzer catches typos and the
/// catalog in docs/CAPABILITIES.md is grep-able.
library;

abstract class SpaceCaps {
  static const featureObservations = 'feature_observations';
  static const featureMedicationLog = 'feature_medication_log';
  static const featureFieldTrips = 'feature_field_trips';
  static const featureMealLogging = 'feature_meal_logging';
  static const featureNapLogging = 'feature_nap_logging';
  static const featureDiaperLogging = 'feature_diaper_logging';
  static const featureIncidentReports = 'feature_incident_reports';
  static const featureFamilyLogin = 'feature_family_login';
  static const featureBilling = 'feature_billing';
  static const stateCompliance = 'state_compliance';
  static const pickupWindowStart = 'pickup_window_start';
  static const pickupWindowEnd = 'pickup_window_end';
  static const defaultClassSize = 'default_class_size';
  static const photoDefaultConsent = 'photo_default_consent';

  /// PIN that unlocks the kid-mode lock. Stored as a string on the
  /// Space's capabilities JSONB so a director can change it from
  /// program settings. Default is `null` — kid-mode unlock falls
  /// back to the 5-tap-corner gesture without a PIN check.
  ///
  /// SECURITY POSTURE: this is "device-level" lockdown — a kid
  /// physically holding the device can't escape without staff
  /// help. It's NOT a security boundary against an adversary with
  /// access to the local SQLite (the PIN ships with the synced
  /// space row). Future versions may move this to a per-Member
  /// PIN stored encrypted; for now the program-wide PIN is fine
  /// for the "hand the tablet to a kid" use case.
  static const staffPin = 'staff_pin';

  /// Vertical key for this Space — drives `verticalLabelsProvider`.
  /// One of: `childcare` / `construction` / `healthcare` /
  /// `hospitality` / `manufacturing`. Missing or unknown values
  /// fall back to `childcare` (the current install base).
  ///
  /// Stored on the JSONB blob (rather than a dedicated column) so a
  /// vertical flip is a single capability write, no schema
  /// migration. The provider re-reads on every Space row update.
  static const vertical = 'vertical';
}

/// Childcare-specific keys that live on **Subject** `capabilities`
/// JSONB. Holds the structured "health & medical" intake that
/// supplements the existing `subjects.allergies` text column.
///
/// Stored on the JSONB bag (no new schema columns) so other verticals
/// can add their own intake namespaces here without ever touching
/// these keys. A construction "subject" (project) would register
/// `ConstructionSubjectCaps.specSheetUrl` etc. under its own
/// namespace; the medical keys below stay NULL for non-childcare
/// rows.
///
/// List-shaped values (medications, conditions) are serialized as
/// JSON-encoded list-of-strings (`'["Albuterol","EpiPen Jr"]'`).
/// Empty list = no value. The form deserializes on read,
/// re-encodes on write.
abstract class ChildcareSubjectCaps {
  /// JSON-encoded `List<String>` of medication names. Free-form
  /// strings (the form lets staff type names; this is not a coded
  /// drug catalog — that would require its own database).
  static const medications = 'childcare_medications';

  /// JSON-encoded `List<String>` of medical conditions ("asthma",
  /// "type 1 diabetes", "mild ADHD"). Free-form per above.
  static const medicalConditions = 'childcare_medical_conditions';

  /// Plain text — short summary of an IEP or 504 plan, what staff
  /// need to know day-to-day. Full document goes in `attachments`
  /// when we wire that surface.
  static const iepSummary = 'childcare_iep_summary';

  /// Primary care physician's name + phone. Two separate keys so
  /// the form can validate phone formatting independently.
  static const physicianName = 'childcare_physician_name';
  static const physicianPhone = 'childcare_physician_phone';

  /// Free-text "in an emergency, do this" guidance from the
  /// guardians. Different from the generic Subject.notes — that's
  /// general staff notes; this is specifically the emergency
  /// playbook.
  static const emergencyInstructions = 'childcare_emergency_instructions';
}

/// Vertical-agnostic member capabilities. Every vertical we
/// target (childcare, construction, healthcare, hospitality,
/// manufacturing) has analogs of these.
///
/// **DO NOT add childcare-specific verbs here** (no "diaper" /
/// "nap" / "pickup" — those belong in [ChildcareCaps]). Per the
/// Council audit's vertical-readiness blocker #3, the global
/// capability catalog should split into:
///
///   - [CoreCaps] (this class, alias `MemberCaps`) — every vertical
///   - [ChildcareCaps] — childcare-only
///   - future: `ConstructionCaps`, `HealthcareCaps`, etc.
///
/// MemberCaps is kept as an alias so existing call sites compile
/// unchanged. New code should reference `CoreCaps.foo` or
/// `ChildcareCaps.foo` directly; the alias is for migration
/// convenience only.
abstract class CoreCaps {
  static const canObserve = 'can_observe';
  static const canTakeAttendance = 'can_take_attendance';
  static const canDrive = 'can_drive';
  static const canOpenBuilding = 'can_open_building';
  static const canCloseBuilding = 'can_close_building';
  static const canViewBilling = 'can_view_billing';
  static const canInviteStaff = 'can_invite_staff';
  static const canViewAuditLog = 'can_view_audit_log';
  static const canActAsDirector = 'can_act_as_director';
  static const canManageSchedule = 'can_manage_schedule';
  static const isSpecialist = 'is_specialist';
}

/// Childcare-specific verbs. A construction app would never set
/// these; a healthcare app would replace `canAuthorizePickup` with
/// `canSignRelease`, replace `canRecord{Meal,Nap,Diaper}` with
/// chart-note kinds, etc.
abstract class ChildcareCaps {
  static const canRecordMeal = 'can_record_meal';
  static const canRecordNap = 'can_record_nap';
  static const canRecordDiaper = 'can_record_diaper';
  static const canAdministerMedication = 'can_administer_medication';
  static const canAuthorizePickup = 'can_authorize_pickup';
}

/// Alias for backward compatibility. Lets the existing call sites
/// (`MemberCaps.canObserve`, `MemberCaps.canRecordDiaper`, etc.)
/// keep working while new code migrates to `CoreCaps` / `ChildcareCaps`.
/// All keys forward to the same string values — no runtime change.
///
/// Certifications were previously stored as JSONB on this same caps
/// blob (keys `certifications` + `certification_expirations`). They
/// are now a first-class entity (`member_certifications` table /
/// CertActions). See UX_DECISIONS §8 and migration
/// 20260518000010_member_certifications.sql which backfilled the
/// existing rows + dropped both keys.
abstract class MemberCaps {
  // Core (vertical-agnostic)
  static const String canObserve = CoreCaps.canObserve;
  static const String canTakeAttendance = CoreCaps.canTakeAttendance;
  static const String canDrive = CoreCaps.canDrive;
  static const String canOpenBuilding = CoreCaps.canOpenBuilding;
  static const String canCloseBuilding = CoreCaps.canCloseBuilding;
  static const String canViewBilling = CoreCaps.canViewBilling;
  static const String canInviteStaff = CoreCaps.canInviteStaff;
  static const String canViewAuditLog = CoreCaps.canViewAuditLog;
  static const String canActAsDirector = CoreCaps.canActAsDirector;
  static const String canManageSchedule = CoreCaps.canManageSchedule;
  static const String isSpecialist = CoreCaps.isSpecialist;

  // Childcare-specific (kept here for compat; prefer ChildcareCaps
  // in new code so it's grep-able by vertical)
  static const String canRecordMeal = ChildcareCaps.canRecordMeal;
  static const String canRecordNap = ChildcareCaps.canRecordNap;
  static const String canRecordDiaper = ChildcareCaps.canRecordDiaper;
  static const String canAdministerMedication =
      ChildcareCaps.canAdministerMedication;
  static const String canAuthorizePickup = ChildcareCaps.canAuthorizePickup;
}

abstract class GroupCaps {
  static const ageBand = 'age_band';
  static const tracksDiapers = 'tracks_diapers';
  static const tracksNaps = 'tracks_naps';
  static const tracksMealsDetailed = 'tracks_meals_detailed';
  static const tracksBottleFeeds = 'tracks_bottle_feeds';
  static const napSchedule = 'nap_schedule';
  static const hasOutdoorTime = 'has_outdoor_time';
  static const hasFieldTrips = 'has_field_trips';
  static const curriculumUnitId = 'curriculum_unit_id';
  static const bilingualLanguages = 'bilingual_languages';
}

abstract class SubjectCaps {
  // Tracking flags — inherit from Group unless set explicitly here.
  static const tracksDiapers = 'tracks_diapers';
  static const tracksNaps = 'tracks_naps';
  static const tracksBottleFeeds = 'tracks_bottle_feeds';
  static const tracksPottyTraining = 'tracks_potty_training';

  // Medical
  static const allergies = 'allergies';
  static const dietary = 'dietary';
  static const medications = 'medications';
  static const medicalConditions = 'medical_conditions';

  // Education
  static const hasIep = 'has_iep';
  static const iepNotes = 'iep_notes';
  static const requiresOneOnOne = 'requires_one_on_one';

  // Pickup / family
  static const photoConsent = 'photo_consent';
  static const pickupStrict = 'pickup_strict';
  static const authorizedPickupGuardianIds = 'authorized_pickup_guardian_ids';
  static const photoVisibility = 'photo_visibility';

  /// Free-form list of additional people authorized to pick up this
  /// child (beyond the formal guardian rows). Stored as a list of
  /// maps: [{"name": "...", "phone": "...", "notes": "..."}].
  static const pickupPeople = 'pickup_people';

  // Behavioral / care notes
  static const comfortItems = 'comfort_items';
  static const napRoutine = 'nap_routine';
  static const transitionNotes = 'transition_notes';
}

/// Age band values for GroupCaps.ageBand.
abstract class AgeBands {
  static const infant = 'infant';
  static const toddler = 'toddler';
  static const preschool = 'preschool';
  static const prek = 'prek';
  static const mixed = 'mixed';

  static const List<String> all = [infant, toddler, preschool, prek, mixed];

  static String label(String key) => switch (key) {
    infant => 'Infant (0–18 mo)',
    toddler => 'Toddler (18 mo–3 yr)',
    preschool => 'Preschool (3–5 yr)',
    prek => 'Pre-K (4–5 yr)',
    mixed => 'Mixed ages',
    _ => key,
  };
}

/// Member role default capability bundles (per docs/CAPABILITIES.md).
/// Used when creating a new Member or applying an Invite — the caller's
/// chosen role seeds the capabilities map.
abstract class RoleBundles {
  static Map<String, dynamic> defaultsFor(String role) {
    switch (role) {
      case 'director':
        return <String, dynamic>{
          MemberCaps.canObserve: true,
          MemberCaps.canTakeAttendance: true,
          MemberCaps.canRecordMeal: true,
          MemberCaps.canRecordNap: true,
          MemberCaps.canRecordDiaper: true,
          MemberCaps.canOpenBuilding: true,
          MemberCaps.canCloseBuilding: true,
          MemberCaps.canAuthorizePickup: true,
          MemberCaps.canViewBilling: true,
          MemberCaps.canInviteStaff: true,
          MemberCaps.canViewAuditLog: true,
          MemberCaps.canActAsDirector: true,
          MemberCaps.canManageSchedule: true,
          // Cert-gated; stays false until a cert is added.
          MemberCaps.canAdministerMedication: false,
          MemberCaps.canDrive: false,
        };
      case 'lead_teacher':
        return <String, dynamic>{
          MemberCaps.canObserve: true,
          MemberCaps.canTakeAttendance: true,
          MemberCaps.canRecordMeal: true,
          MemberCaps.canRecordNap: true,
          MemberCaps.canRecordDiaper: true,
          MemberCaps.canOpenBuilding: true,
          MemberCaps.canCloseBuilding: true,
          MemberCaps.canAuthorizePickup: true,
          MemberCaps.canManageSchedule: true,
        };
      case 'teacher':
        return <String, dynamic>{
          MemberCaps.canObserve: true,
          MemberCaps.canTakeAttendance: true,
          MemberCaps.canRecordMeal: true,
          MemberCaps.canRecordNap: true,
          MemberCaps.canRecordDiaper: true,
          MemberCaps.canManageSchedule: true,
        };
      case 'assistant':
        return <String, dynamic>{
          MemberCaps.canTakeAttendance: true,
          MemberCaps.canRecordMeal: true,
          MemberCaps.canRecordNap: true,
          MemberCaps.canRecordDiaper: true,
        };
      default:
        return const <String, dynamic>{};
    }
  }
}

/// Default Group caps derived from age band — used as fallback when
/// a Group hasn't set explicit overrides.
abstract class AgeBandDefaults {
  static Map<String, dynamic> forBand(String? band) {
    switch (band) {
      case AgeBands.infant:
        return <String, dynamic>{
          GroupCaps.tracksDiapers: true,
          GroupCaps.tracksNaps: true,
          GroupCaps.tracksBottleFeeds: true,
          GroupCaps.tracksMealsDetailed: true,
          GroupCaps.hasOutdoorTime: false,
          GroupCaps.hasFieldTrips: false,
        };
      case AgeBands.toddler:
        return <String, dynamic>{
          GroupCaps.tracksDiapers: true,
          GroupCaps.tracksNaps: true,
          GroupCaps.tracksBottleFeeds: false,
          GroupCaps.tracksMealsDetailed: true,
          GroupCaps.hasOutdoorTime: true,
          GroupCaps.hasFieldTrips: false,
        };
      case AgeBands.preschool:
      case AgeBands.prek:
        return <String, dynamic>{
          GroupCaps.tracksDiapers: false,
          GroupCaps.tracksNaps: true,
          GroupCaps.tracksBottleFeeds: false,
          GroupCaps.tracksMealsDetailed: false,
          GroupCaps.hasOutdoorTime: true,
          GroupCaps.hasFieldTrips: true,
        };
      case AgeBands.mixed:
      default:
        return <String, dynamic>{
          GroupCaps.tracksDiapers: false,
          GroupCaps.tracksNaps: true,
          GroupCaps.tracksBottleFeeds: false,
          GroupCaps.tracksMealsDetailed: false,
          GroupCaps.hasOutdoorTime: true,
          GroupCaps.hasFieldTrips: false,
        };
    }
  }
}
