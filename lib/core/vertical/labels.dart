import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-vertical UI labels — childcare today, construction / healthcare /
/// hospitality / manufacturing later. Drives every user-visible string
/// that names the engine primitives (Space / Member / Group / Subject /
/// Entry).
///
/// Today the provider returns the childcare default. When the
/// vertical-config column lands on `public.spaces`, the provider will
/// switch on `space.capabilities['vertical']` and return the matching
/// label set. The widget call sites stay the same — the change is
/// one file.
///
/// See [docs/APP_GUIDE.md](docs/APP_GUIDE.md) Part 2 for the full
/// vertical map.
class VerticalLabels {
  const VerticalLabels({
    required this.vertical,
    required this.space,
    required this.spacePlural,
    required this.member,
    required this.memberPlural,
    required this.group,
    required this.groupPlural,
    required this.subject,
    required this.subjectPlural,
    required this.entry,
    required this.entryPlural,
    required this.checkinVerb,
    required this.attendanceNoun,
  });

  /// Vertical key — `childcare` / `construction` / `healthcare` /
  /// `hospitality` / `manufacturing`. Drives feature gates too (e.g.
  /// hide pickup/ in construction).
  final String vertical;

  /// "Program" (childcare), "Company" (construction), "Clinic"
  /// (healthcare), etc.
  final String space;
  final String spacePlural;

  /// "Staff" (childcare), "Crew" or "Foreman" (construction depending
  /// on context — use [memberPlural] for collective).
  final String member;
  final String memberPlural;

  /// "Classroom" (childcare), "Crew" or "Job site" (construction),
  /// "Department" / "Shift" (healthcare), etc.
  final String group;
  final String groupPlural;

  /// THE thing the work is about. "Child" (childcare), "Project" /
  /// "Unit" (construction), "Patient" (healthcare), "Guest" /
  /// "Reservation" (hospitality), "Work order" / "Unit"
  /// (manufacturing).
  final String subject;
  final String subjectPlural;

  /// Atomic work-log row. "Observation" (childcare), "Daily update"
  /// / "Incident" (construction), "Chart note" / "Vitals"
  /// (healthcare), "Order note" / "Allergy" (hospitality), "Defect
  /// log" (manufacturing).
  final String entry;
  final String entryPlural;

  /// Verb for "log a {subject}'s arrival." "Check in" (childcare),
  /// "Sign in" (construction site), "Triage in" (clinic), "Seat"
  /// (restaurant). Used by attendance + handoff surfaces.
  final String checkinVerb;

  /// What attendance is called in this vertical. "Attendance"
  /// (childcare), "Site sign-in" (construction), "Roll call"
  /// (healthcare shift), "Cover counts" (hospitality), "Shift
  /// sign-in" (manufacturing).
  final String attendanceNoun;
}

/// Static map of per-vertical label sets. New vertical → add a key
/// here; one place to extend.
abstract class _VerticalLabelPresets {
  static const childcare = VerticalLabels(
    vertical: 'childcare',
    space: 'Program',
    spacePlural: 'Programs',
    member: 'Staff',
    memberPlural: 'Staff',
    group: 'Classroom',
    groupPlural: 'Classrooms',
    subject: 'Child',
    subjectPlural: 'Children',
    entry: 'Observation',
    entryPlural: 'Observations',
    checkinVerb: 'Check in',
    attendanceNoun: 'Attendance',
  );

  static const construction = VerticalLabels(
    vertical: 'construction',
    space: 'Company',
    spacePlural: 'Companies',
    member: 'Worker',
    memberPlural: 'Crew',
    group: 'Crew',
    groupPlural: 'Crews',
    subject: 'Project',
    subjectPlural: 'Projects',
    entry: 'Daily update',
    entryPlural: 'Daily updates',
    checkinVerb: 'Sign in',
    attendanceNoun: 'Site sign-in',
  );

  static const healthcare = VerticalLabels(
    vertical: 'healthcare',
    space: 'Clinic',
    spacePlural: 'Clinics',
    member: 'Staff',
    memberPlural: 'Staff',
    group: 'Department',
    groupPlural: 'Departments',
    subject: 'Patient',
    subjectPlural: 'Patients',
    entry: 'Chart note',
    entryPlural: 'Chart notes',
    checkinVerb: 'Triage in',
    attendanceNoun: 'Roll call',
  );

  static const hospitality = VerticalLabels(
    vertical: 'hospitality',
    space: 'Restaurant',
    spacePlural: 'Restaurants',
    member: 'Staff',
    memberPlural: 'Staff',
    group: 'Section',
    groupPlural: 'Sections',
    subject: 'Guest',
    subjectPlural: 'Guests',
    entry: 'Order note',
    entryPlural: 'Order notes',
    checkinVerb: 'Seat',
    attendanceNoun: 'Cover counts',
  );

  static const manufacturing = VerticalLabels(
    vertical: 'manufacturing',
    space: 'Plant',
    spacePlural: 'Plants',
    member: 'Operator',
    memberPlural: 'Operators',
    group: 'Line',
    groupPlural: 'Lines',
    subject: 'Work order',
    subjectPlural: 'Work orders',
    entry: 'Defect log',
    entryPlural: 'Defect logs',
    checkinVerb: 'Shift in',
    attendanceNoun: 'Shift sign-in',
  );

  static VerticalLabels forKey(String key) {
    switch (key) {
      case 'construction':
        return construction;
      case 'healthcare':
        return healthcare;
      case 'hospitality':
        return hospitality;
      case 'manufacturing':
        return manufacturing;
      case 'childcare':
      default:
        return childcare;
    }
  }

  /// All vertical keys + their default labels — drives the picker in
  /// program settings and any catalog UI. Order is "most-built-out
  /// first" so new installs see childcare on top (the install base
  /// it's actually shipped against today).
  static const List<VerticalLabels> allPresets = [
    childcare,
    construction,
    healthcare,
    hospitality,
    manufacturing,
  ];
}

/// Convenience accessor for the catalog of vertical presets — used
/// by the program-settings vertical picker.
List<VerticalLabels> get allVerticalPresets => _VerticalLabelPresets.allPresets;

/// The active vertical's label set. Reads
/// `space.capabilities['vertical']` off the signed-in Space row and
/// returns the matching preset; missing or unknown keys fall back
/// to childcare.
///
/// Widgets do `ref.watch(verticalLabelsProvider).subject` instead of
/// the literal string "Child". A director flipping the vertical in
/// program settings re-emits this provider through `currentSpace
/// Provider`, and every consuming widget flips together on the next
/// rebuild.
final Provider<VerticalLabels> verticalLabelsProvider =
    Provider<VerticalLabels>((ref) {
      final space = ref.watch(currentSpaceProvider).value;
      if (space == null) return _VerticalLabelPresets.childcare;
      final key = space.caps.getString(SpaceCaps.vertical);
      return _VerticalLabelPresets.forKey(key ?? 'childcare');
    });

/// Cheap accessor for when you don't want the full provider plumbing —
/// e.g. inside a static `_labels` helper. Returns the same childcare
/// default; falls back to it for unknown keys.
VerticalLabels labelsForVerticalKey(String? key) =>
    _VerticalLabelPresets.forKey(key ?? 'childcare');
