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
}

abstract class MemberCaps {
  static const canObserve = 'can_observe';
  static const canTakeAttendance = 'can_take_attendance';
  static const canRecordMeal = 'can_record_meal';
  static const canRecordNap = 'can_record_nap';
  static const canRecordDiaper = 'can_record_diaper';
  static const canAdministerMedication = 'can_administer_medication';
  static const canDrive = 'can_drive';
  static const canOpenBuilding = 'can_open_building';
  static const canCloseBuilding = 'can_close_building';
  static const canAuthorizePickup = 'can_authorize_pickup';
  static const canViewBilling = 'can_view_billing';
  static const canInviteStaff = 'can_invite_staff';
  static const canViewAuditLog = 'can_view_audit_log';
  static const canActAsDirector = 'can_act_as_director';

  /// Can edit the camp schedule — create blocks, assign activities,
  /// schedule field trips. Defaults true for all staff (set per role
  /// in the capability defaults below); directors can revoke per
  /// person from member detail.
  static const canManageSchedule = 'can_manage_schedule';

  /// Marks this member as a "specialist" — narrow-scope staff (yoga
  /// instructor, swim coach, archery lead). Specialists show up in
  /// the schedule activity lead picker; their Today screen defaults
  /// to "what am I leading" instead of "what's the whole camp doing."
  static const isSpecialist = 'is_specialist';
  // Certifications were previously stored as JSONB on this same caps
  // blob (keys `certifications` + `certification_expirations`). They
  // are now a first-class entity (`member_certifications` table /
  // CertActions). See UX_DECISIONS §8 and migration
  // 20260518000010_member_certifications.sql which backfilled the
  // existing rows + dropped both keys.
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
