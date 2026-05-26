import 'package:differentworld/core/db/dao/activities_dao.dart';
import 'package:differentworld/core/db/dao/attachments_dao.dart';
import 'package:differentworld/core/db/dao/attendance_dao.dart';
import 'package:differentworld/core/db/dao/captures_dao.dart';
import 'package:differentworld/core/db/dao/certifications_dao.dart';
import 'package:differentworld/core/db/dao/dismissed_insights_dao.dart';
import 'package:differentworld/core/db/dao/entries_dao.dart';
import 'package:differentworld/core/db/dao/exports_dao.dart';
import 'package:differentworld/core/db/dao/group_members_dao.dart';
import 'package:differentworld/core/db/dao/groups_dao.dart';
import 'package:differentworld/core/db/dao/guardians_dao.dart';
import 'package:differentworld/core/db/dao/invites_dao.dart';
import 'package:differentworld/core/db/dao/locations_dao.dart';
import 'package:differentworld/core/db/dao/members_dao.dart';
import 'package:differentworld/core/db/dao/messages_dao.dart';
import 'package:differentworld/core/db/dao/schedule_dao.dart';
import 'package:differentworld/core/db/dao/spaces_dao.dart';
import 'package:differentworld/core/db/dao/subjects_dao.dart';
import 'package:differentworld/core/db/dao/surveys_dao.dart';
import 'package:differentworld/core/db/dao/tasks_dao.dart';
import 'package:differentworld/core/db/dao/trips_dao.dart';
import 'package:differentworld/core/db/dao/vehicles_dao.dart';
import 'package:drift/drift.dart';
import 'package:drift_sqlite_async/drift_sqlite_async.dart';
// Both drift and powersync export a `Column` class — only import what we
// actually need from powersync to avoid the ambiguity.
import 'package:powersync/powersync.dart' show PowerSyncDatabase;

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
  TextColumn get status => text()(); // present / absent / late / early_pickup / excused
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

/// One row per (subject, survey-template). The questions themselves
/// are app-defined templates (see `survey_templates.dart`); only the
/// answers a kid gave land here, keyed by question_key inside
/// `answers` JSONB. Status: 'draft' (started, partial) or
/// 'completed' (submitted).
class SurveyResponses extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();
  TextColumn get templateId => text()();
  TextColumn get subjectId => text()();
  TextColumn get status => text()();
  TextColumn get recordedBy => text().nullable()();
  TextColumn get answers => text()(); // JSON string keyed by question_key
  TextColumn get startedAt => text()();
  TextColumn get completedAt => text().nullable()();
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

@DriftDatabase(
  tables: [Spaces, Members, Groups, Subjects, AttendanceRecords, Invites,
          GroupMembers, Entries, Guardians, SubjectGuardians,
          Vehicles, VehicleLogs, MemberCertifications, Attachments,
          SurveyResponses, DismissedInsights, Captures, Tasks, Messages,
          Exports, ExportRecipients,
          // Camp scheduling.
          Locations, Activities, ScheduleBlocks, TripLogistics,
          TripVehicles, PermissionSlips, Headcounts],
  daos: [
    AttachmentsDao,
    AttendanceDao,
    CapturesDao,
    CertificationsDao,
    DismissedInsightsDao,
    EntriesDao,
    ExportsDao,
    GroupMembersDao,
    GroupsDao,
    GuardiansDao,
    InvitesDao,
    MembersDao,
    MessagesDao,
    SpacesDao,
    SubjectsDao,
    SurveysDao,
    TasksDao,
    VehiclesDao,
    // Camp scheduling.
    LocationsDao,
    ActivitiesDao,
    ScheduleDao,
    TripsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(PowerSyncDatabase powerSync)
      : super(SqliteAsyncDriftConnection(powerSync));

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

  // -- Cross-table writes (members + spaces) -------------------------------

  /// Two writes in one transaction:
  ///   1. INSERT the new space row.
  ///   2. UPDATE the current user's member row to point at it AND promote
  ///      them to director (the role bundle that gates space-admin writes).
  /// PowerSync's CRUD queue picks both up and uploads to Supabase.
  Future<void> createSpaceForMember({
    required String spaceId,
    required String spaceName,
    required String memberId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
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
    });
  }
}
