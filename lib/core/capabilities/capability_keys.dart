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

  /// The director's day-template library — a JSON-encoded list of
  /// duration-block day shapes (see features/schedule/day_template.dart).
  /// String cap (JSON); director-authored, read-mostly, no table.
  static const dayTemplates = 'day_templates';

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

  /// Free-text specialty key for `role: specialist` members
  /// (afterschool 4-12). Values come from [SpecialtyKeys]. Stored on
  /// `member.capabilities.specialty`; null/missing for non-specialists.
  ///
  /// Composable: a Group Leader who ALSO coaches doesn't need a
  /// `lead_coach` role — they're `role: lead_teacher` with their
  /// specialty stored on the capabilities blob. (Today the UI only
  /// surfaces specialty for `role: specialist`; future enhancement
  /// could show it as a secondary tag for any role.)
  static const specialty = 'specialty';
}

/// Closed catalog of specialty values for `role: specialist` members.
/// Keys are stable (used in DB); labels are human-readable.
abstract class SpecialtyKeys {
  static const coach = 'coach';
  static const tutor = 'tutor';
  static const healthAide = 'health_aide';
  static const behavior = 'behavior';
  static const inclusion = 'inclusion';
  static const reading = 'reading';
  static const bilingual = 'bilingual';

  /// All known specialties in canonical UI order. Picker chips render
  /// in this order; doesn't include "Other" — if a program needs a
  /// novel specialty, add it here rather than typing free-text.
  static const all = <String>[
    coach,
    tutor,
    healthAide,
    behavior,
    inclusion,
    reading,
    bilingual,
  ];

  /// Human label for a specialty key. Unknown keys degrade to a
  /// title-cased echo of the key so unfamiliar values still render.
  static String labelOf(String? key) {
    return switch (key) {
      coach => 'Coach',
      tutor => 'Tutor',
      healthAide => 'Health Aide',
      behavior => 'Behavior Specialist',
      inclusion => 'Inclusion Aide',
      reading => 'Reading Specialist',
      bilingual => 'Bilingual / ESL Specialist',
      _ => (key ?? '').isEmpty
          ? 'Specialist'
          : key!.replaceAll('_', ' ').split(' ').map((w) {
              if (w.isEmpty) return w;
              return w[0].toUpperCase() + w.substring(1);
            }).join(' '),
    };
  }
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

/// Subject-level caps. These are CHILDCARE-FLAVOURED today — the class
/// name is preserved for backwards compat with the many call sites
/// (alerts_section, pickup_providers, etc.); a future refactor will
/// rename to `ChildcareSubjectCaps` and re-home the keys under a
/// per-vertical namespace pattern (parallel to `ChildcareCaps` vs
/// `CoreCaps` for members).
///
/// All keys live on `subjects.capabilities` JSONB — no schema columns.
/// Other verticals add their own subject-intake keys under a sibling
/// class without touching these.
abstract class SubjectCaps {
  // Tracking flags — inherit from Group unless set explicitly here.
  static const tracksDiapers = 'tracks_diapers';
  static const tracksNaps = 'tracks_naps';
  static const tracksBottleFeeds = 'tracks_bottle_feeds';
  static const tracksPottyTraining = 'tracks_potty_training';

  // Medical
  static const allergies = 'allergies';
  static const dietary = 'dietary';

  /// Free-form text of current medications. Health profile sheet
  /// edits as comma-separated string; AlertsSection renders verbatim.
  static const medications = 'medications';

  /// Free-form text of medical conditions. Health profile sheet edits
  /// as comma-separated string.
  static const medicalConditions = 'medical_conditions';

  /// Primary physician name + phone, free-text. Surfaced on the
  /// health profile card.
  static const physicianName = 'physician_name';
  static const physicianPhone = 'physician_phone';

  /// Free-text "what to do if something happens" guidance from the
  /// guardians. Different from the generic Subject.notes column —
  /// that's general staff notes; this is specifically the emergency
  /// playbook.
  static const emergencyInstructions = 'emergency_instructions';

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

/// Default capability bundle for a (vertical, role) pair.
///
/// Used when creating a Member or accepting an Invite — the chosen
/// role seeds the caps map. Per-vertical so a "manager" in
/// hospitality and a "lead_teacher" in childcare can default to
/// different verbs even though they overlap on `CoreCaps`.
///
/// The bundles live in code (not a per-space `role_catalog` table)
/// because the agnostic-engine principle is "don't add tables to
/// hold what code constants can express." When a customer needs to
/// override a role bundle for their space, the existing per-Member
/// capability overrides on `members.capabilities` are the escape
/// hatch.
///
/// Verticals that don't have a hand-written bundle for a role
/// degrade to an empty map — callers should still merge over the
/// member's existing caps so legacy values survive.
abstract class RoleBundles {
  /// Bundle for [role] in [vertical]. Pass the vertical key from
  /// `verticalLabelsProvider`. Defaults to `'childcare'` for the
  /// many existing call sites that haven't been threaded through
  /// yet.
  static Map<String, dynamic> defaultsFor(
    String role, {
    String vertical = 'childcare',
  }) {
    return switch (vertical) {
      'construction' => _construction[role] ?? const <String, dynamic>{},
      'healthcare' => _healthcare[role] ?? const <String, dynamic>{},
      'hospitality' => _hospitality[role] ?? const <String, dynamic>{},
      'manufacturing' => _manufacturing[role] ?? const <String, dynamic>{},
      _ => _childcare[role] ?? const <String, dynamic>{},
    };
  }

  /// The "director-equivalent" role key in this vertical — the role
  /// whose default bundle sets `CoreCaps.canActAsDirector: true`.
  /// Used by safety gates (e.g. last-director-protection in the role
  /// picker) that need to know "who's the admin in this space?"
  /// without hard-coding 'director' across verticals.
  static String directorRoleFor(String vertical) {
    return switch (vertical) {
      'construction' => 'pm',
      'healthcare' => 'physician',
      'hospitality' => 'gm',
      'manufacturing' => 'production_manager',
      _ => 'director',
    };
  }

  /// Role keys this vertical offers — the role picker uses this to
  /// scope its dropdown to vertical-appropriate options. Childcare
  /// surfaces director / lead_teacher / teacher / assistant;
  /// construction surfaces pm / foreman / journeyman / apprentice /
  /// subcontractor; etc. Order is "most senior first" so the
  /// dropdown reads top-down by authority.
  static List<String> rolesFor(String vertical) {
    return switch (vertical) {
      'construction' => const [
          'pm',
          'foreman',
          'journeyman',
          'apprentice',
          'subcontractor',
        ],
      'healthcare' => const [
          'physician',
          'np',
          'rn',
          'tech',
          'admin',
        ],
      'hospitality' => const [
          'gm',
          'manager',
          'server',
          'cook',
          'host',
        ],
      'manufacturing' => const [
          'production_manager',
          'line_lead',
          'operator',
          'qa',
          'maintenance',
        ],
      _ => const [
          'director',
          'lead_teacher',
          'teacher',
          'substitute',
          'specialist',
          'kitchen',
        ],
    };
  }

  // ---------------------------------------------------------------------------
  // Per-vertical bundle maps. Each one is `roleKey → cap bundle`.
  // Childcare bundles can include `ChildcareCaps`; other verticals stick
  // to `CoreCaps` (vertical-agnostic verbs) until they have their own
  // domain caps catalog (`ConstructionCaps`, `HealthcareCaps`, ...).
  // ---------------------------------------------------------------------------

  static const Map<String, Map<String, dynamic>> _childcare = {
    'director': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      ChildcareCaps.canRecordMeal: true,
      ChildcareCaps.canRecordNap: true,
      ChildcareCaps.canRecordDiaper: true,
      CoreCaps.canOpenBuilding: true,
      CoreCaps.canCloseBuilding: true,
      ChildcareCaps.canAuthorizePickup: true,
      CoreCaps.canViewBilling: true,
      CoreCaps.canInviteStaff: true,
      CoreCaps.canViewAuditLog: true,
      CoreCaps.canActAsDirector: true,
      CoreCaps.canManageSchedule: true,
      // Cert-gated; stays false until a cert is added.
      ChildcareCaps.canAdministerMedication: false,
      CoreCaps.canDrive: false,
    },
    'lead_teacher': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      ChildcareCaps.canRecordMeal: true,
      ChildcareCaps.canRecordNap: true,
      ChildcareCaps.canRecordDiaper: true,
      CoreCaps.canOpenBuilding: true,
      CoreCaps.canCloseBuilding: true,
      ChildcareCaps.canAuthorizePickup: true,
      CoreCaps.canManageSchedule: true,
    },
    'teacher': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      ChildcareCaps.canRecordMeal: true,
      ChildcareCaps.canRecordNap: true,
      ChildcareCaps.canRecordDiaper: true,
      CoreCaps.canManageSchedule: true,
    },
    // Substitute: temporary coverage (filling in for the day / shift).
    // Low default trust — can mark attendance + observe, but no
    // building access, no pickup authorization, no schedule edits.
    // The hiring director can promote individual caps per substitute
    // if the substitute is well-known to the program.
    'substitute': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      ChildcareCaps.canRecordMeal: true,
    },
    // Specialist: subject-matter staff (coach / tutor / health aide /
    // behavior / inclusion / reading / bilingual). Sees assigned
    // cohorts only — scoping handled by `group_members` row, not by
    // the bundle. Their specific area is on member.capabilities
    // under `ChildcareCaps.specialty` (see catalog there).
    'specialist': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      ChildcareCaps.canRecordMeal: true,
      CoreCaps.canManageSchedule: false,
      ChildcareCaps.canAuthorizePickup: false,
    },
    // Kitchen staff: meals only. Doesn't observe, doesn't take
    // attendance, doesn't see family contacts. The narrowest staff
    // role in the childcare bundle.
    'kitchen': {
      ChildcareCaps.canRecordMeal: true,
    },
  };

  /// Construction: PM owns the project + finances; foreman runs the
  /// site day-to-day; journeyman / apprentice are field workers;
  /// subcontractor is an external party with read-mostly access.
  static const Map<String, Map<String, dynamic>> _construction = {
    'pm': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      CoreCaps.canViewBilling: true,
      CoreCaps.canInviteStaff: true,
      CoreCaps.canViewAuditLog: true,
      CoreCaps.canActAsDirector: true,
      CoreCaps.canManageSchedule: true,
      CoreCaps.canOpenBuilding: true,
      CoreCaps.canCloseBuilding: true,
      CoreCaps.canDrive: false,
    },
    'foreman': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      CoreCaps.canManageSchedule: true,
      CoreCaps.canOpenBuilding: true,
      CoreCaps.canCloseBuilding: true,
      CoreCaps.canDrive: false,
    },
    'journeyman': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
    },
    'apprentice': {
      CoreCaps.canObserve: true,
    },
    'subcontractor': {
      CoreCaps.canObserve: true,
    },
  };

  /// Healthcare: physician has clinical authority; NP/RN cover most
  /// of the day-to-day; tech / admin are the support roles.
  static const Map<String, Map<String, dynamic>> _healthcare = {
    'physician': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      CoreCaps.canActAsDirector: true,
      CoreCaps.canManageSchedule: true,
      CoreCaps.canViewAuditLog: true,
      CoreCaps.canInviteStaff: true,
    },
    'np': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      CoreCaps.canManageSchedule: true,
    },
    'rn': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      CoreCaps.canManageSchedule: true,
    },
    'tech': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
    },
    'admin': {
      CoreCaps.canViewBilling: true,
      CoreCaps.canInviteStaff: true,
      CoreCaps.canManageSchedule: true,
    },
  };

  /// Hospitality: GM has full authority; manager covers shifts;
  /// server / cook / host are the floor roles.
  static const Map<String, Map<String, dynamic>> _hospitality = {
    'gm': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      CoreCaps.canViewBilling: true,
      CoreCaps.canInviteStaff: true,
      CoreCaps.canViewAuditLog: true,
      CoreCaps.canActAsDirector: true,
      CoreCaps.canManageSchedule: true,
      CoreCaps.canOpenBuilding: true,
      CoreCaps.canCloseBuilding: true,
    },
    'manager': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      CoreCaps.canManageSchedule: true,
      CoreCaps.canOpenBuilding: true,
      CoreCaps.canCloseBuilding: true,
    },
    'server': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
    },
    'cook': {
      CoreCaps.canObserve: true,
    },
    'host': {
      CoreCaps.canTakeAttendance: true,
    },
  };

  /// Manufacturing: production manager runs the floor; line leads
  /// supervise; operator / QA / maintenance are the workers.
  static const Map<String, Map<String, dynamic>> _manufacturing = {
    'production_manager': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      CoreCaps.canActAsDirector: true,
      CoreCaps.canManageSchedule: true,
      CoreCaps.canViewBilling: true,
      CoreCaps.canInviteStaff: true,
      CoreCaps.canViewAuditLog: true,
      CoreCaps.canOpenBuilding: true,
      CoreCaps.canCloseBuilding: true,
    },
    'line_lead': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
      CoreCaps.canManageSchedule: true,
    },
    'operator': {
      CoreCaps.canObserve: true,
      CoreCaps.canTakeAttendance: true,
    },
    'qa': {
      CoreCaps.canObserve: true,
    },
    'maintenance': {
      CoreCaps.canObserve: true,
    },
  };
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
