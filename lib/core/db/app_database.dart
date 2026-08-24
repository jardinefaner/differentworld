import 'package:differentworld/core/db/dao/activities_dao.dart';
import 'package:differentworld/core/db/dao/activity_supplies_dao.dart';
import 'package:differentworld/core/db/dao/attachments_dao.dart';
import 'package:differentworld/core/db/dao/attendance_dao.dart';
import 'package:differentworld/core/db/dao/captures_dao.dart';
import 'package:differentworld/core/db/dao/certifications_dao.dart';
import 'package:differentworld/core/db/dao/character_sheets_dao.dart';
import 'package:differentworld/core/db/dao/content_bank_dao.dart';
import 'package:differentworld/core/db/dao/dismissed_insights_dao.dart';
import 'package:differentworld/core/db/dao/entries_dao.dart';
import 'package:differentworld/core/db/dao/events_dao.dart';
import 'package:differentworld/core/db/dao/exports_dao.dart';
import 'package:differentworld/core/db/dao/group_members_dao.dart';
import 'package:differentworld/core/db/dao/groups_dao.dart';
import 'package:differentworld/core/db/dao/guardians_dao.dart';
import 'package:differentworld/core/db/dao/invites_dao.dart';
import 'package:differentworld/core/db/dao/locations_dao.dart';
import 'package:differentworld/core/db/dao/members_dao.dart';
import 'package:differentworld/core/db/dao/messages_dao.dart';
import 'package:differentworld/core/db/dao/missions_dao.dart';
import 'package:differentworld/core/db/dao/placements_dao.dart';
import 'package:differentworld/core/db/dao/room_events_dao.dart';
import 'package:differentworld/core/db/dao/rotation_dao.dart';
import 'package:differentworld/core/db/dao/schedule_dao.dart';
import 'package:differentworld/core/db/dao/spaces_dao.dart';
import 'package:differentworld/core/db/dao/subjects_dao.dart';
import 'package:differentworld/core/db/dao/supplies_dao.dart';
import 'package:differentworld/core/db/dao/surveys_dao.dart';
import 'package:differentworld/core/db/dao/tasks_dao.dart';
import 'package:differentworld/core/db/dao/trips_dao.dart';
import 'package:differentworld/core/db/dao/vehicles_dao.dart';
import 'package:differentworld/core/db/dao/weekly_template_dao.dart';
import 'package:drift/drift.dart';
import 'package:drift_sqlite_async/drift_sqlite_async.dart';
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

// Drift mirrors of the tables PowerSync owns. Engine-level (universal)
// names per docs/NAMING.md. PowerSync never lets Drift migrate the
// schema — these classes exist purely for typed reads/writes/streams.
//
// Column names auto-derived snake_case from camelCase Dart fields
// (`displayName` ↔ `display_name`).

class Spaces extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get slug => text().nullable()();
  TextColumn get settings => text()();
  TextColumn get capabilities => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Members extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text().nullable()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get capabilities => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get name => text()();
  TextColumn get ageRange => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get capabilities => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get groupId => text().nullable()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get dob => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get allergies => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get capabilities => text()();
  // Per-kid drop-off / pickup windows. Stored as 'HH:mm' or 'HH:mm:ss'
  // strings (no date) because PowerSync's local SQLite has no native
  // TIME type. Time-of-day only; assumed local to the space timezone.
  TextColumn get dropoffWindowStart => text().nullable()();
  TextColumn get dropoffWindowEnd => text().nullable()();
  TextColumn get pickupWindowStart => text().nullable()();
  TextColumn get pickupWindowEnd => text().nullable()();

  /// `enrolled` | `alumni`. A child is NEVER deleted to make room for a new
  /// intake — the year rollover turns them into an alumnus, and they keep
  /// every observation, photo tag, message and book they ever had
  /// (docs/ROLLOVER.md).
  ///
  /// **Nullable, deliberately, even though the server column is NOT NULL.**
  /// PowerSync's local columns are always nullable, and a newly-added one
  /// reads NULL for every row already on the device until the sync that
  /// carries it arrives. Declaring it non-null here would make Drift throw
  /// while mapping those rows — so the type mirrors the local reality, and
  /// every query treats NULL as enrolled.
  TextColumn get status => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class AttendanceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get groupId => text().nullable()();
  TextColumn get subjectId => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get status =>
      text()(); // present / absent / late / early_pickup / excused
  TextColumn get notes => text().nullable()();
  TextColumn get recordedBy => text()();
  TextColumn get recordedAt => text()();
  TextColumn get updatedAt => text()();
  // Wave 105: who LAST touched this row. recordedBy stays as the
  // original author (set once at insert); lastUpdatedBy is rewritten
  // on every upsert. The attendance row surfaces a "Last updated by
  // X · 2m ago" footnote when the value diverges from recordedBy
  // (i.e. someone overwrote the original write).
  TextColumn get lastUpdatedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Invites extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get email => text().nullable()();
  TextColumn get code => text().nullable()();
  TextColumn get role => text()();

  /// Set for guardian-intent invites — the child this guardian is
  /// being invited as a parent / family member for. Null for staff.
  TextColumn get subjectId => text().nullable()();
  TextColumn get capabilities => text()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get expiresAt => text().nullable()();
  TextColumn get acceptedAt => text().nullable()();
  TextColumn get acceptedBy => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-classroom staff assignment. A member can be assigned to many
/// groups; a group has many members. Directors are implicitly
/// assigned to every group in their space (no rows needed).
///
/// Carries its own `id` PK because PowerSync requires an id column
/// on every replicated table — composite-PK join tables fail SQLite
/// constraint 1811 ("id is required") on insert otherwise. The
/// server-side `(group_id, member_id)` UNIQUE constraint keeps
/// re-assigning idempotent.
class GroupMembers extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get memberId => text()();
  TextColumn get spaceId => text()();
  TextColumn get roleInGroup => text().nullable()();
  TextColumn get assignedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A parent / family contact attached to one or more subjects via
/// the join table [SubjectGuardians]. NOT a Member — staff and
/// guardians are distinct identities. A guardian doesn't sign in
/// (yet); when family-login ships they'll auth into the family lens.
class Guardians extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();

  /// Links to auth.users.id once this guardian accepts an invite and
  /// signs into the family app. Null until then — directors add
  /// guardian contact info long before the parent ever logs in.
  TextColumn get userId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get relationship => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  IntColumn get authorizedForPickup => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Join: which guardians are linked to which subjects. Many-to-many.
/// Same PowerSync constraint as [GroupMembers] — needs an explicit
/// `id` PK; the (subjectId, guardianId) pair is UNIQUE on the server.
class SubjectGuardians extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId => text()();
  TextColumn get guardianId => text()();
  TextColumn get spaceId => text()();
  IntColumn get isPrimary => integer().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The unified daily-log table. `kind` discriminates between
/// 'observation', 'meal', 'nap', 'diaper', 'incident', etc.
/// `details` holds a JSON blob whose shape depends on `kind`.
///
/// The Dart getter is named `body` because `text` collides with
/// Drift's `text()` column-builder method and breaks codegen. The
/// underlying Postgres / PowerSync column is still called `text` —
/// see the `.named('text')` mapping.
class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get groupId => text().nullable()();
  TextColumn get subjectId => text().nullable()();
  // Live-block capture: the schedule block this moment happened during
  // (null = untagged / nothing live). See docs/LIVE_BLOCK_CONTEXT.md.
  TextColumn get scheduleBlockId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get body => text().named('text').nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get details => text()(); // JSON string
  TextColumn get recordedBy => text()();
  TextColumn get recordedAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fleet vehicle. Directors manage the list; drivers (members with
/// `can_drive` cap-gated by Driver certification) perform the
/// check-out / check-in via [VehicleLogs] rows.
class Vehicles extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get name => text()();
  TextColumn get make => text().nullable()();
  TextColumn get model => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get licensePlate => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get capabilities => text()(); // JSON string
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Event stream for fleet activity. One row per check-out or check-in.
/// Current state of a vehicle = derived from the latest row by
/// vehicle_id ordered desc by created_at.
class VehicleLogs extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get vehicleId => text()();
  TextColumn get kind => text()(); // 'checkout' | 'checkin'
  TextColumn get driverMemberId => text()();
  IntColumn get odometer => integer().nullable()();
  TextColumn get fuelLevel => text().nullable()();
  TextColumn get items => text()(); // JSON string of inspection results
  TextColumn get notes => text().nullable()();
  TextColumn get bodyDamageNotes => text().nullable()();

  /// JSON array of boarded subject ids — the trip headcount (board at
  /// check-out, tap each off at check-in). Nullable + always set explicitly
  /// by the client (a server `default` is a no-op over PowerSync); read as
  /// null → empty list.
  TextColumn get roster => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A staff member's hold of a single certification (MAT / CPR / Driver
/// / etc). Promoted from JSONB-on-`members.capabilities` per
/// UX_DECISIONS §8 so we get proper lifecycle (issued, expires) and
/// can query "expiring soon" without scanning JSON blobs.
class MemberCertifications extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get memberId => text()();
  TextColumn get certKey => text()();
  TextColumn get issuedAt => text().nullable()(); // ISO date
  TextColumn get expiresAt => text().nullable()(); // ISO date
  TextColumn get notes => text().nullable()();
  TextColumn get documentUrl => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-member snooze for derived insights. Insights themselves have
/// no DB row — they're computed on-device — but the dismissal *is*
/// a real piece of state, so it gets a table. Unique on
/// (member_id, insight_id): re-dismissing replaces the prior row.
class DismissedInsights extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get memberId => text()();
  TextColumn get insightId => text()();
  TextColumn get dismissedUntil => text().nullable()(); // ISO timestamp
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per survey-take session. Wave 138: surveys are now
/// fully anonymous — each "Start" creates a fresh row with
/// `subject_id = null`. The questions themselves are app-defined
/// templates (see `survey_templates.dart`); only the answers a kid
/// gave land here, keyed by question_key inside `answers` JSONB.
/// Identity (age_band / grade / school) is captured on the first
/// page of the survey-take flow. Status: 'draft' (started, partial)
/// or 'completed' (submitted). Legacy rows (pre-Wave-138) had
/// `subject_id` populated; the Wave 138 migration scrubbed those to
/// NULL to anonymize without dropping the answer data.
class SurveyResponses extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get templateId => text()();
  // Wave 138: nullable — anonymous responses have no kid linkage.
  TextColumn get subjectId => text().nullable()();
  TextColumn get status => text()();
  TextColumn get recordedBy => text().nullable()();
  TextColumn get answers => text()(); // JSON string keyed by question_key
  TextColumn get startedAt => text()();
  TextColumn get completedAt => text().nullable()();
  // Wave 120: the kid's chosen TTS voice for this template, e.g.
  // `aura-2-thalia-en`. Null until they pick on the first question;
  // once set, it persists so subsequent sessions skip the picker.
  TextColumn get voiceId => text().nullable()();
  // Wave 135: anonymized identity captured at the start of the
  // survey-take flow. Used by the table view to label rows without
  // exposing the kid's name. All three are nullable — older rows
  // from before the picker shipped won't have them.
  TextColumn get ageBand => text().nullable()();
  TextColumn get grade => text().nullable()();
  TextColumn get school => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Wave 135: per-program catalog of survey identity-picker options.
/// One row per (program, dimension, label). Director's first kid
/// adds a label via the "+" button on the survey-take identity
/// page; subsequent kids see it pre-existing in the picker.
class SurveyPickerOptions extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();

  /// One of 'age_band' / 'grade' / 'school' (server-side CHECK).
  TextColumn get dimension => text()();
  TextColumn get label => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Photo / PDF / audio attached to any entity. First-class per
/// UX_DECISIONS §8 so photos have proper identity (caption,
/// sort_order), can be queried independently ("all photos this week"),
/// and live in one canonical table instead of being a `photo_url`
/// column on every parent.
///
/// `entityKind` is a string discriminator: 'entry' | 'subject' |
/// 'member' | 'vehicle' | 'certification' | future kinds. Keep
/// lowercase-singular by convention.
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get entityKind => text()();
  TextColumn get entityId => text()();
  TextColumn get url => text()();
  TextColumn get thumbUrl => text().nullable()();
  TextColumn get mimeType => text()();
  TextColumn get caption => text().nullable()();
  IntColumn get sortOrder => integer().nullable()();
  TextColumn get uploadedBy => text().nullable()();
  TextColumn get takenAt => text().nullable()();
  // Tag axes (migration 20260621000001): the child the photo is OF, the child
  // who SHOT it (their progress folder), and the activity/block it came from.
  TextColumn get subjectId => text().nullable()();
  TextColumn get capturedBySubjectId => text().nullable()();
  TextColumn get scheduleBlockId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The Capture inbox row. See migration
/// `20260518000014_captures.sql` for the framework rationale —
/// quick "I noticed…" thoughts that get triaged later into Entries,
/// Tasks, Insights, or discarded.
class Captures extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get authorId => text().nullable()();
  TextColumn get body => text()();
  TextColumn get status => text()(); // 'open' | 'promoted' | 'discarded'
  TextColumn get promotedToKind => text().nullable()();
  TextColumn get promotedToId => text().nullable()();
  TextColumn get promotedSubjectId => text().nullable()();
  TextColumn get processedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tasks — the third destination for a triaged capture, and a
/// first-class to-do entity. See migration `20260518000015_tasks.sql`.
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get authorId => text().nullable()();
  TextColumn get subjectId => text().nullable()();
  TextColumn get body => text()();
  TextColumn get status => text()(); // 'open' | 'done' | 'discarded'
  TextColumn get dueAt => text().nullable()();
  TextColumn get completedBy => text().nullable()();
  TextColumn get completedAt => text().nullable()();
  TextColumn get createdFromCaptureId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Messages — staff↔guardian per-child threads. Thread identity is
/// the (subject_id, guardian_id) pair; no separate threads table.
/// See migration `20260518000016_messages.sql`.
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get subjectId => text()();
  TextColumn get guardianId => text()();
  TextColumn get senderKind => text()(); // 'staff' | 'guardian'
  TextColumn get senderMemberId => text().nullable()();
  TextColumn get senderGuardianId => text().nullable()();
  TextColumn get body => text()();
  TextColumn get readAt => text().nullable()();

  /// JSON-array of guardian UUIDs who've read past this message.
  /// Devon-persona: divorced parents share a kid; per-guardian
  /// read-state lets staff see "Seen by Mom only" vs "Seen by both."
  /// Empty string / null is treated as `'[]'` at the reader site.
  ///
  /// Nullable here because the local SQLite schema (PowerSync-managed)
  /// stores it as TEXT NULL — declaring this as non-nullable in Drift
  /// caused row decoding to throw on every read of a message inserted
  /// before the server's default kicked in, which manifested as
  /// "Could not load this thread" after sending a message (Wave 62).
  TextColumn get readByGuardianIds => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Exports — the audit + snapshot trail for every PDF / CSV the
/// program generates. Bytes live in Supabase Storage; this row
/// carries the metadata + JSON snapshot of the source data used
/// to render it. See migration `20260519000001_exports.sql`.
class Exports extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get authorId => text().nullable()();
  TextColumn get templateId => text()();
  TextColumn get templateVersion => text()();
  TextColumn get subjectId => text().nullable()();
  TextColumn get groupId => text().nullable()();
  TextColumn get status => text()(); // 'draft' | 'sent' | 'archived'
  TextColumn get format => text()(); // 'pdf' | 'csv'
  TextColumn get storagePath => text().nullable()();
  TextColumn get snapshotJson => text()(); // JSON blob
  TextColumn get note => text().nullable()();
  TextColumn get generatedAt => text()();
  TextColumn get sentAt => text().nullable()();
  TextColumn get archivedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-export recipient list. Each row records one address the
/// document was sent to (guardian, internal member, or free-text
/// external party) and the channel + delivery state.
class ExportRecipients extends Table {
  TextColumn get id => text()();
  TextColumn get exportId => text()();
  TextColumn get spaceId => text()();
  TextColumn get kind => text()(); // 'guardian' | 'member' | 'external'
  TextColumn get guardianId => text().nullable()();
  TextColumn get memberId => text().nullable()();
  TextColumn get externalLabel => text().nullable()();
  TextColumn get externalEmail => text().nullable()();
  TextColumn get channel => text()();
  TextColumn get state => text()(); // pending|delivered|failed|manual
  TextColumn get stateDetail => text().nullable()();
  TextColumn get sentAt => text().nullable()();
  TextColumn get readAt => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Physical place an activity happens. See locations migration in
/// supabase/migrations/20260519000003_camp_scheduling.sql.
class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get capacity => integer().nullable()();
  IntColumn get isOutdoor => integer()(); // 0/1
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Join: which supplies an activity needs, and how many (docs/SUPPLIES.md
/// pack lists). One row per (activity, supply); `quantity` nullable.
class ActivitySupplies extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get activityId => text()();
  TextColumn get supplyId => text()();
  RealColumn get quantity => real().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The persistent in-world SELF (Different World; docs/WORLD.md,
/// docs/WORLD_DESIGN.md). 1:1 with a subject. `avatarUrl` is the child's
/// self-DRAWING — kept separate from the subject's administrative `photoUrl`
/// so a crayon portrait never clobbers the pickup-ID photo. Age is derived
/// from completed dailies (no stored streak — the no-punishment vow).
class CharacterSheets extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get subjectId => text()();
  TextColumn get chosenName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get bornOn => text().nullable()(); // ISO date
  TextColumn get culture => text().nullable()();
  TextColumn get capabilities => text().nullable()(); // raw JSON
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Real jobs a kid (or counselor) actually does, with real evidence
/// (docs/MISSIONS.md). The grounded counterpart to the imaginative Role
/// Cards. `actions` is a JSON array string (parse client-side);
/// `isActive` is 0/1; `evidenceKind` is photo/count/note/check.
class Missions extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  TextColumn get tagline => text().nullable()();
  TextColumn get why => text().nullable()();
  TextColumn get builds => text().nullable()();
  TextColumn get rules => text().nullable()();
  TextColumn get actions => text().nullable()();
  TextColumn get evidenceKind => text()();
  IntColumn get minAge => integer().nullable()();
  IntColumn get maxAge => integer().nullable()();
  IntColumn get isActive => integer()(); // 0/1
  IntColumn get sort => integer()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The content bank (docs/CONTENT_BANK.md). One banked activity item —
/// generated once, synced, reused, so AI is never called on the hot path
/// of a play. `spaceId` is nullable: NULL = global (AI / shared-curated,
/// written server-side), set = this program's own (crowd-grown).
/// `payload` is the activity's JSON shape, stored raw. The Drift row is
/// named `ContentItemRow` (via @DataClassName) so it doesn't collide with
/// the domain `ContentItem` in content_bank.dart.
@DataClassName('ContentItemRow')
class ContentItems extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get payload => text()();
  TextColumn get fingerprint => text()();
  TextColumn get source => text()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A named period — '2026–27' or 'Summer 2026'. One table serves a school
/// year and a session because an afterschool program needs both words and
/// the shape is identical (docs/ROLLOVER.md).
class Terms extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get name => text()();
  TextColumn get startsOn => text()();
  TextColumn get endsOn => text().nullable()();

  /// 0/1. Exactly one per space, enforced by a partial unique index server-side.
  IntColumn get isCurrent => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One child, in one room, for one period — the history that makes a new
/// intake additive. `subjects.groupId` remains the CURRENT room so every
/// existing roster query keeps working; this sits beside it.
///
/// Deliberately NOT `Enrollments`: `enrollments` has meant staff↔classroom
/// since the foundation migration. Same word, different relationship.
class Placements extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get subjectId => text()();

  /// Null = enrolled for the period but not yet placed in a room.
  TextColumn get groupId => text().nullable()();
  TextColumn get termId => text()();
  TextColumn get startedAt => text()();

  /// Null = still open. Rollover CLOSES rather than deletes.
  TextColumn get endedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One ARRANGEMENT of a cohort (docs/ROTATION.md). The pair history is
/// derived by folding these rows — `groups` already says who was together —
/// so there is no second table to keep in step, and undo is a delete.
///
/// `groups` / `satOut` are raw JSON strings (jsonb server-side); `seed` is
/// text because it is an opaque reproducibility token, never arithmetic.
class RotationRounds extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get groupId => text()();
  IntColumn get roundNo => integer()();
  TextColumn get mode => text()();
  IntColumn get n => integer()();
  TextColumn get remainder => text()();
  TextColumn get groups => text()();
  TextColumn get satOut => text()();
  TextColumn get seed => text()();
  IntColumn get newPairs => integer()();
  IntColumn get repeatPairs => integer()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The ONE fairness log every Room instrument writes to — who was picked,
/// who spoke first, who spoke and for how long, points, which prompt was
/// used. They all answer the same question (who has had their share, and how
/// recently), so they share a store; separate ones would make
/// cross-instrument fairness impossible.
class RoomEvents extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get groupId => text()();

  /// Null when the event is about the room rather than a child.
  TextColumn get subjectId => text().nullable()();
  TextColumn get kind => text()();

  /// Kind-dependent magnitude: seconds spoken, points awarded, else 1.
  IntColumn get value => integer()();
  TextColumn get detail => text().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The program's real-world inventory (docs/SUPPLIES.md). A catalog
/// referenced by id from the things that consume it. `quantity` /
/// `lowStockThreshold` are doubles; `photoUrl` is a Storage path.
class Supplies extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  RealColumn get quantity => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get locationId => text().nullable()();
  RealColumn get lowStockThreshold => real().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A defined activity that can be scheduled. Owned by the staff member
/// who created it. Activities are reusable across blocks.
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get ownerMemberId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get defaultLocationId => text().nullable()();
  IntColumn get defaultDurationMinutes => integer().nullable()();
  TextColumn get supplies => text().nullable()();
  IntColumn get ageMin => integer().nullable()();
  IntColumn get ageMax => integer().nullable()();
  IntColumn get maxCapacity => integer().nullable()();
  IntColumn get isOutdoor => integer()(); // 0/1
  TextColumn get indoorAltActivityId => text().nullable()();
  TextColumn get capabilities => text()();
  TextColumn get archivedAt => text().nullable()();
  // Wave 153: visual / filter fields. Both optional — programs with
  // monotone palettes leave color null and we fall back to the theme
  // primaryContainer on the grid.
  TextColumn get color => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The day's plan, one row per (date × cohort × time block). Block
/// boundaries are per-row, not derived from a global grid — see the
/// migration comment for why.
class ScheduleBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get groupId => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get startAt => text()(); // ISO 8601 timestamptz
  TextColumn get endAt => text()();
  // Wave A (formless create): free-text block name. Shown on the card
  // when set; an activity link (color/defaults) can attach later.
  TextColumn get title => text().nullable()();
  TextColumn get activityId => text().nullable()();
  TextColumn get leadMemberId => text().nullable()();

  /// Pat persona — director-set substitute when the planned lead is
  /// absent today. Reads use `COALESCE(substitute, lead)` so the
  /// substitute sees the block in their LeadingTodayCard and the
  /// absent person's card no longer shows it.
  TextColumn get leadSubstituteMemberId => text().nullable()();
  TextColumn get locationOverrideId => text().nullable()();
  TextColumn get kind => text()(); // on_site / field_trip / break / closed
  TextColumn get notes => text().nullable()();
  // Wave 155: status of this block — 'planned' / 'skipped' / 'cancelled'.
  // The today view dims skipped/cancelled blocks; the family lens shows
  // the reason inline.
  //
  // NULLABLE on purpose: PowerSync owns the local SQLite schema, so a
  // Drift `.withDefault('planned')` is a no-op there — the column is
  // created without a default, and any insert that omits `status` (Drift
  // lets you, *because* of the default) lands a NULL, which then crashes
  // the row-mapper on read ("Couldn't load this cohort's schedule" on
  // every add). Treating it as nullable makes reads NULL-safe; inserts
  // set 'planned' explicitly, and readers coalesce NULL → planned.
  TextColumn get status => text().nullable()();
  TextColumn get statusReason => text().nullable()();

  /// Wave 165: optional link back to a curriculum session shipped in
  /// the binary (e.g. 'photo.s1.click-game'). NULL for ad-hoc blocks.
  /// When set, the schedule grid tiles render a small badge and the
  /// block-edit screen offers a deep-link to the curriculum session
  /// detail.
  TextColumn get curriculumSessionSlug => text().nullable()();

  /// Wave 166.2: shared UUID for blocks that came out of one
  /// "Repeat…" action. Null for ad-hoc one-off blocks. Future
  /// "edit all in series" / "delete all in series" affordances key
  /// on this column.
  TextColumn get recurrenceId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One-to-one with a schedule_block whose kind = 'field_trip'.
class TripLogistics extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get scheduleBlockId => text()();
  TextColumn get destination => text()();
  TextColumn get destinationAddress => text().nullable()();
  TextColumn get departureAt => text().nullable()();
  TextColumn get returnAt => text().nullable()();
  IntColumn get requiresPermissionSlip => integer()(); // 0/1
  TextColumn get notes => text().nullable()();
  // Field-trip maps. destination_* = the geocoded/manual destination pin
  // (where the group is HEADED); pinned_* = the group's live "we are here"
  // pin from GPS, with pinnedAt the ISO-8601 instant of the last drop. All
  // nullable — a trip has no coordinates until prep / until it pins itself.
  RealColumn get destinationLat => real().nullable()();
  RealColumn get destinationLng => real().nullable()();
  RealColumn get pinnedLat => real().nullable()();
  RealColumn get pinnedLng => real().nullable()();
  TextColumn get pinnedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Vehicle assignment for a trip. `manifest` is a JSON array of
/// subject ids (decoded server-side via the supabase_connector
/// jsonbColumns set).
class TripVehicles extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get tripLogisticsId => text()();
  TextColumn get vehicleId => text()();
  TextColumn get driverMemberId => text().nullable()();
  TextColumn get manifest => text()(); // JSON array
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One slip per (subject, trip). Tracks whether the paper / digital
/// permission is on file; doesn't replace the paper itself.
class PermissionSlips extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get subjectId => text()();
  TextColumn get tripLogisticsId => text()();
  TextColumn get signerGuardianId => text().nullable()();
  TextColumn get signerName => text().nullable()();
  TextColumn get signedAt => text()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A counted snapshot at a transition. Audit trail for field-trip
/// transitions and high-ratio on-site activities.
class Headcounts extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get scheduleBlockId => text()();
  TextColumn get checkpointLabel => text()();
  IntColumn get count => integer()();
  IntColumn get expectedCount => integer().nullable()();
  TextColumn get takenByMemberId => text().nullable()();
  TextColumn get takenAt => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Wave 154: weekly schedule template. One row per (space, name).
/// V1 ships with a single "Default week" template per space.
class WeeklyTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get name => text()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Wave 154: a single slot inside a weekly template — one row per
/// (template, group, day_of_week, start_time). `dayOfWeek` is 0..6
/// matching ISO Monday..Sunday.
class WeeklyTemplateBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get templateId => text()();
  TextColumn get spaceId => text()();
  TextColumn get groupId => text()();
  IntColumn get dayOfWeek => integer()();
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  TextColumn get activityId => text().nullable()();
  TextColumn get leadMemberId => text().nullable()();
  TextColumn get locationOverrideId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Wave 158: one-off events that overlay or replace the regular
/// schedule for a date. Distinct from activities (reusable catalog
/// items) — events are the parties, guest speakers, fundraisers,
/// closures. May span multiple cohorts.
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get date => text()(); // ISO YYYY-MM-DD
  TextColumn get startAt => text().nullable()();
  TextColumn get endAt => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get color => text().nullable()();

  /// JSON-encoded list of group IDs the event affects. Empty = all
  /// cohorts in the space.
  TextColumn get groupIds => text()();

  /// One of 'overlay' / 'replaces' / 'closes_day'.
  TextColumn get mode => text()();
  TextColumn get locationId => text().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Spaces, Members, Groups, Subjects, AttendanceRecords, Invites,
    GroupMembers, Entries, Guardians, SubjectGuardians,
    Vehicles, VehicleLogs, MemberCertifications, Attachments,
    SurveyResponses, SurveyPickerOptions,
    DismissedInsights, Captures, Tasks, Messages,
    Exports, ExportRecipients,
    // Different World — the persistent in-world self.
    CharacterSheets,
    // Supplies inventory.
    Supplies,
    // Missions — real jobs with evidence.
    Missions,
    // Activity ↔ supplies pack-list join.
    ActivitySupplies,
    // Camp scheduling.
    Locations, Activities, ScheduleBlocks, TripLogistics,
    TripVehicles, PermissionSlips, Headcounts,
    // Wave 158: one-off events.
    Events,
    // Wave 154: weekly template authoring.
    WeeklyTemplates, WeeklyTemplateBlocks,
    // Content bank — generate-once-reuse activity content.
    ContentItems,
    // The Room console — arrangements + the shared fairness log.
    RotationRounds, RoomEvents,
    // Year rollover — named periods + child-in-room-for-a-period.
    Terms, Placements,
  ],
  daos: [
    AttachmentsDao,
    RotationDao,
    RoomEventsDao,
    PlacementsDao,
    AttendanceDao,
    CapturesDao,
    CharacterSheetsDao,
    CertificationsDao,
    DismissedInsightsDao,
    EntriesDao,
    EventsDao,
    ExportsDao,
    GroupMembersDao,
    GroupsDao,
    GuardiansDao,
    InvitesDao,
    MembersDao,
    MessagesDao,
    MissionsDao,
    ContentBankDao,
    SpacesDao,
    SubjectsDao,
    SuppliesDao,
    SurveysDao,
    TasksDao,
    VehiclesDao,
    // Camp scheduling.
    LocationsDao,
    ActivitiesDao,
    ActivitySuppliesDao,
    ScheduleDao,
    TripsDao,
    // Wave 154: weekly template + generate-blocks.
    WeeklyTemplateDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(PowerSyncDatabase powerSync)
    : super(SqliteAsyncDriftConnection(powerSync));

  /// Test-only: open over a plain Drift executor (e.g.
  /// `NativeDatabase.memory()`) instead of PowerSync, so the action layer can
  /// be unit-tested. Production ALWAYS uses the PowerSync constructor (the
  /// `migration` strategy stays no-op because PowerSync owns the real schema);
  /// tests materialize the schema themselves with
  /// `await db.createMigrator().createAll()`. See docs/EXTENDING.md.
  @visibleForTesting
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // PowerSync owns the schema; do not create tables here.
    },
    onUpgrade: (m, from, to) async {
      // PowerSync-managed; schema changes flow from server.
    },
  );

  // -- Cross-table writes -------------------------------------------------

  /// Delete a supply AND its activity_supplies links in one transaction.
  /// Local SQLite does not enforce FK cascade (PRAGMA foreign_keys is off);
  /// the server cascades, so without this the local links orphan and a later
  /// delete-then-reinsert would reference a server-deleted supply_id and stall
  /// the CRUD queue. Both deletes route through the queue (typed Drift APIs).
  Future<void> deleteSupplyCascade(String supplyId) async {
    await transaction(() async {
      await (delete(
        activitySupplies,
      )..where((r) => r.supplyId.equals(supplyId))).go();
      await (delete(supplies)..where((s) => s.id.equals(supplyId))).go();
    });
  }

  /// Two writes in one transaction:
  ///   1. INSERT the new space row.
  ///   2. UPDATE the current user's member row to point at it AND promote
  ///      them to director (the role bundle that gates space-admin writes).
  /// Wave 153: also seeds the activity catalog with ~30 starter items
  /// so a brand-new program's `/schedule/template` and
  /// `/activities` screens aren't empty on day one.
  /// PowerSync's CRUD queue picks all writes up and uploads to Supabase.
  Future<void> createSpaceForMember({
    required String spaceId,
    required String spaceName,
    required String memberId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    const uuid = Uuid();
    await transaction(() async {
      await into(spaces).insert(
        SpacesCompanion.insert(
          id: spaceId,
          name: spaceName,
          settings: '{}',
          capabilities: '{}',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await (update(members)..where((m) => m.id.equals(memberId))).write(
        MembersCompanion(
          spaceId: Value(spaceId),
          role: const Value('director'),
          updatedAt: Value(now),
        ),
      );
      // Wave 153: seed the starter activity pack. Idempotent at the
      // call-site level (we only run this on space creation), and
      // each starter gets a freshly generated UUID — a director
      // adding a custom "Reading" activity later won't collide.
      for (final starter in _starterActivities) {
        await into(activities).insert(
          ActivitiesCompanion.insert(
            id: uuid.v4(),
            spaceId: spaceId,
            name: starter.name,
            description: Value(starter.description),
            defaultDurationMinutes: Value(starter.duration),
            supplies: Value(starter.supplies),
            isOutdoor: starter.isOutdoor ? 1 : 0,
            capabilities: '{}',
            color: Value(starter.color),
            category: Value(starter.category),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }
}

/// Wave 153: starter activity pack seeded into every new program.
/// Tuned for the afterschool 4-12 vertical (CLAUDE.md primary
/// product context). A director can edit / archive any of them
/// later; the point is to land on a populated catalog so the
/// scheduler doesn't open empty.
class _StarterActivity {
  const _StarterActivity({
    required this.name,
    required this.description,
    required this.duration,
    required this.category,
    required this.color,
    this.supplies = '',
    this.isOutdoor = false,
  });
  final String name;
  final String description;
  final int duration;
  final String category;
  final String color;
  final String supplies;
  final bool isOutdoor;
}

const _starterActivities = <_StarterActivity>[
  // Snack / transition
  _StarterActivity(
    name: 'Snack',
    description: 'Daily snack — handwashing first.',
    duration: 15,
    category: 'snack',
    color: '#FFB74D',
  ),
  _StarterActivity(
    name: 'Arrival',
    description: 'Kids check in, drop off bags, settle in.',
    duration: 15,
    category: 'transition',
    color: '#90A4AE',
  ),
  _StarterActivity(
    name: 'Dismissal',
    description: 'Pack up, line up, sign-out.',
    duration: 15,
    category: 'transition',
    color: '#90A4AE',
  ),
  _StarterActivity(
    name: 'Bathroom break',
    description: 'Scheduled bathroom + water break.',
    duration: 10,
    category: 'transition',
    color: '#90A4AE',
  ),

  // Quiet
  _StarterActivity(
    name: 'Reading hour',
    description: 'Self-selected reading; teacher reads aloud on request.',
    duration: 30,
    category: 'quiet',
    color: '#7986CB',
    supplies: 'Books, cushions',
  ),
  _StarterActivity(
    name: 'Homework help',
    description: 'Teacher available for homework support.',
    duration: 45,
    category: 'quiet',
    color: '#7986CB',
    supplies: 'Pencils, paper, sharpeners',
  ),
  _StarterActivity(
    name: 'Quiet choice',
    description: 'Puzzles, drawing, journaling — kid picks.',
    duration: 30,
    category: 'quiet',
    color: '#7986CB',
  ),
  _StarterActivity(
    name: 'Story circle',
    description: 'Teacher-led story with discussion.',
    duration: 20,
    category: 'quiet',
    color: '#7986CB',
  ),

  // Creative
  _StarterActivity(
    name: 'Art studio',
    description: 'Open art-making — paint, collage, clay, mixed media.',
    duration: 45,
    category: 'creative',
    color: '#F06292',
    supplies: 'Paint, brushes, paper, smocks',
  ),
  _StarterActivity(
    name: 'Music & movement',
    description: 'Songs, simple instruments, dance.',
    duration: 30,
    category: 'creative',
    color: '#F06292',
    supplies: 'Speaker, shakers, scarves',
  ),
  _StarterActivity(
    name: 'Drama games',
    description: 'Improv prompts, charades, freeze tag.',
    duration: 30,
    category: 'creative',
    color: '#F06292',
  ),
  _StarterActivity(
    name: 'Maker time',
    description: 'Cardboard, tape, recycled materials — open build.',
    duration: 45,
    category: 'creative',
    color: '#F06292',
    supplies: 'Cardboard, tape, scissors, markers',
  ),

  // STEM / learning
  _StarterActivity(
    name: 'STEM challenge',
    description: 'Weekly engineering / science prompt.',
    duration: 45,
    category: 'creative',
    color: '#4DB6AC',
    supplies: 'Per challenge',
  ),
  _StarterActivity(
    name: 'Nature lesson',
    description: 'Observation walk + journaling.',
    duration: 30,
    category: 'creative',
    color: '#4DB6AC',
    supplies: 'Journals, magnifying glasses',
    isOutdoor: true,
  ),
  _StarterActivity(
    name: 'Cooking',
    description: 'Simple no-cook recipe; allergy check.',
    duration: 45,
    category: 'creative',
    color: '#4DB6AC',
    supplies: 'Per recipe',
  ),

  // Active / outdoor
  _StarterActivity(
    name: 'Outdoor play',
    description: 'Open recess on the yard.',
    duration: 45,
    category: 'active',
    color: '#81C784',
    isOutdoor: true,
  ),
  _StarterActivity(
    name: 'Sports rotation',
    description: 'Teacher-led — soccer, basketball, kickball.',
    duration: 45,
    category: 'active',
    color: '#81C784',
    supplies: 'Balls, cones, pinnies',
    isOutdoor: true,
  ),
  _StarterActivity(
    name: 'Tag games',
    description: 'Group games — sharks & minnows, freeze tag.',
    duration: 30,
    category: 'active',
    color: '#81C784',
    isOutdoor: true,
  ),
  _StarterActivity(
    name: 'Obstacle course',
    description: 'Teacher-set; rotate weekly.',
    duration: 30,
    category: 'active',
    color: '#81C784',
    supplies: 'Cones, hoops, mats',
    isOutdoor: true,
  ),
  _StarterActivity(
    name: 'Capoeira',
    description: 'Instructor-led martial arts class.',
    duration: 45,
    category: 'active',
    color: '#81C784',
  ),
  _StarterActivity(
    name: 'Yoga',
    description: 'Guided kid-friendly yoga.',
    duration: 25,
    category: 'active',
    color: '#81C784',
    supplies: 'Mats',
  ),
  _StarterActivity(
    name: 'Indoor games',
    description: 'Rain-day fallback — board games, gym games.',
    duration: 45,
    category: 'active',
    color: '#81C784',
  ),

  // Free choice / special
  _StarterActivity(
    name: 'Free choice',
    description: 'Kid picks from open stations.',
    duration: 30,
    category: 'special',
    color: '#BA68C8',
  ),
  _StarterActivity(
    name: 'Community circle',
    description: 'Group share — highs / lows / questions.',
    duration: 20,
    category: 'special',
    color: '#BA68C8',
  ),
  _StarterActivity(
    name: 'Friday celebration',
    description: 'Recap of the week + small group reward.',
    duration: 30,
    category: 'special',
    color: '#BA68C8',
  ),
  _StarterActivity(
    name: 'Special guest',
    description: 'Visitor or themed program; teacher confirms day-of.',
    duration: 45,
    category: 'special',
    color: '#BA68C8',
  ),
  _StarterActivity(
    name: 'Movie / wind-down',
    description: 'Calm activity to close the day.',
    duration: 30,
    category: 'special',
    color: '#BA68C8',
  ),
  _StarterActivity(
    name: 'Field trip',
    description: 'Off-site visit — author through the trip wizard.',
    duration: 120,
    category: 'special',
    color: '#FFD54F',
  ),
];
