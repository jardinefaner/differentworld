import 'package:drift/drift.dart';
import 'package:drift_sqlite_async/drift_sqlite_async.dart';
// Both drift and powersync export a `Column` class — only import what we
// actually need from powersync to avoid the ambiguity.
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

@DriftDatabase(
  tables: [Spaces, Members, Groups, Subjects, AttendanceRecords, Invites,
          GroupMembers, Entries, Guardians, SubjectGuardians,
          Vehicles, VehicleLogs],
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

  // -- Members --------------------------------------------------------------

  Stream<Member?> watchMember(String userId) {
    return (select(members)..where((m) => m.id.equals(userId)))
        .watchSingleOrNull();
  }

  /// One-shot read by ID. Use this — not a captured widget prop — when
  /// a write needs the latest `capabilities` to avoid clobbering
  /// concurrent edits to other cap keys.
  Future<Member?> findMemberById(String id) {
    return (select(members)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
  }

  /// Same pattern as findMemberById, for Space-level capability writes.
  Future<Space?> findSpaceById(String id) {
    return (select(spaces)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

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

  // -- Groups ---------------------------------------------------------------

  Stream<List<Group>> watchGroupsInSpace(String spaceId) {
    return (select(groups)
          ..where((g) => g.spaceId.equals(spaceId))
          ..orderBy([(g) => OrderingTerm(expression: g.name)]))
        .watch();
  }

  Stream<Group?> watchGroup(String id) {
    return (select(groups)..where((g) => g.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<void> createGroup({
    required String id,
    required String spaceId,
    required String name,
    String? ageRange,
    String? color,
    String capabilitiesJson = '{}',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(groups).insert(
      GroupsCompanion.insert(
        id: id,
        spaceId: spaceId,
        name: name,
        ageRange: Value(ageRange),
        color: Value(color),
        capabilities: capabilitiesJson,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateGroup({
    required String id,
    String? name,
    String? ageRange,
    String? color,
    String? capabilitiesJson,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(groups)..where((g) => g.id.equals(id))).write(
      GroupsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        ageRange: ageRange == null ? const Value.absent() : Value(ageRange),
        color: color == null ? const Value.absent() : Value(color),
        capabilities: capabilitiesJson == null
            ? const Value.absent()
            : Value(capabilitiesJson),
        updatedAt: Value(now),
      ),
    );
  }

  // -- Capability mutators (write the JSONB column on each entity) ---------

  Future<void> updateSpaceCapabilities(
    String id,
    String capabilitiesJson,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(spaces)..where((s) => s.id.equals(id))).write(
      SpacesCompanion(
        capabilities: Value(capabilitiesJson),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateMemberCapabilities(
    String id,
    String capabilitiesJson,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(members)..where((m) => m.id.equals(id))).write(
      MembersCompanion(
        capabilities: Value(capabilitiesJson),
        updatedAt: Value(now),
      ),
    );
  }

  /// Updates a member's role using the typed Drift API so PowerSync's
  /// CRUD queue picks it up. Don't use `customStatement` for this —
  /// raw SQL bypasses the WAL triggers PowerSync relies on.
  Future<void> updateMemberRole(String id, String role) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(members)..where((m) => m.id.equals(id))).write(
      MembersCompanion(role: Value(role), updatedAt: Value(now)),
    );
  }

  /// Set or clear the member's avatar_url. Pass null to remove the
  /// photo (the underlying Storage object stays — orphans are cheaper
  /// than risking a delete on a still-referenced path).
  Future<void> updateMemberAvatarUrl(String id, String? url) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(members)..where((m) => m.id.equals(id))).write(
      MembersCompanion(
        avatarUrl: Value(url),
        updatedAt: Value(now),
      ),
    );
  }

  /// Set or clear the subject's photo_url.
  Future<void> updateSubjectPhotoUrl(String id, String? url) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(subjects)..where((s) => s.id.equals(id))).write(
      SubjectsCompanion(
        photoUrl: Value(url),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateSubjectCapabilities(
    String id,
    String capabilitiesJson,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(subjects)..where((s) => s.id.equals(id))).write(
      SubjectsCompanion(
        capabilities: Value(capabilitiesJson),
        updatedAt: Value(now),
      ),
    );
  }

  Stream<Space?> watchSpace(String id) {
    return (select(spaces)..where((s) => s.id.equals(id)))
        .watchSingleOrNull();
  }

  Stream<List<Member>> watchMembersInSpace(String spaceId) {
    return (select(members)
          ..where((m) => m.spaceId.equals(spaceId))
          ..orderBy([(m) => OrderingTerm(expression: m.displayName)]))
        .watch();
  }

  Future<void> deleteGroup(String id) async {
    await (delete(groups)..where((g) => g.id.equals(id))).go();
  }

  // -- Subjects -------------------------------------------------------------

  Stream<List<Subject>> watchSubjectsInGroup(String groupId) {
    return (select(subjects)
          ..where((s) => s.groupId.equals(groupId))
          ..orderBy([
            (s) => OrderingTerm(expression: s.firstName),
            (s) => OrderingTerm(expression: s.lastName),
          ]))
        .watch();
  }

  /// One-shot fetch of a subject row by ID. Use this — not a cached
  /// widget prop — when a write needs the latest `capabilities` to
  /// avoid clobbering concurrent edits to other cap keys.
  Future<Subject?> findSubjectById(String id) {
    return (select(subjects)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> createSubject({
    required String id,
    required String spaceId,
    required String groupId,
    required String firstName,
    required String lastName,
    String? dob,
    String? allergies,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(subjects).insert(
      SubjectsCompanion.insert(
        id: id,
        spaceId: spaceId,
        groupId: Value(groupId),
        firstName: firstName,
        lastName: lastName,
        dob: Value(dob),
        allergies: Value(allergies),
        notes: Value(notes),
        capabilities: '{}',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateSubject({
    required String id,
    String? firstName,
    String? lastName,
    String? dob,
    String? allergies,
    String? notes,
    String? groupId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(subjects)..where((s) => s.id.equals(id))).write(
      SubjectsCompanion(
        firstName: firstName == null ? const Value.absent() : Value(firstName),
        lastName: lastName == null ? const Value.absent() : Value(lastName),
        dob: dob == null ? const Value.absent() : Value(dob),
        allergies:
            allergies == null ? const Value.absent() : Value(allergies),
        notes: notes == null ? const Value.absent() : Value(notes),
        groupId: groupId == null ? const Value.absent() : Value(groupId),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteSubject(String id) async {
    await (delete(subjects)..where((s) => s.id.equals(id))).go();
  }

  /// Soft-remove a member from a space — clears their space_id and
  /// resets capabilities to empty. Their auth account still exists, so
  /// they can be re-invited later; their historical attendance / notes
  /// stay attributed to their member id.
  ///
  /// We don't actually `delete(members)` because that would break
  /// foreign-key references from attendance_records, observations, etc.
  Future<void> removeMemberFromSpace(String memberId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(members)..where((m) => m.id.equals(memberId))).write(
      MembersCompanion(
        spaceId: const Value(null),
        capabilities: const Value('{}'),
        updatedAt: Value(now),
      ),
    );
  }

  // -- Attendance -----------------------------------------------------------

  Stream<List<AttendanceRecord>> watchAttendanceForGroupOnDate(
    String groupId,
    String date,
  ) {
    return (select(attendanceRecords)
          ..where(
            (a) => a.groupId.equals(groupId) & a.date.equals(date),
          ))
        .watch();
  }

  /// Insert-or-update an attendance row for a (subject, date) pair.
  Future<void> upsertAttendance({
    required String id,
    required String spaceId,
    required String groupId,
    required String subjectId,
    required String date,
    required String status,
    required String recordedBy,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      final existing = await (select(attendanceRecords)
            ..where(
              (a) => a.subjectId.equals(subjectId) & a.date.equals(date),
            ))
          .getSingleOrNull();

      if (existing != null) {
        await (update(attendanceRecords)
              ..where((a) => a.id.equals(existing.id)))
            .write(
          AttendanceRecordsCompanion(
            status: Value(status),
            notes: notes == null ? const Value.absent() : Value(notes),
            updatedAt: Value(now),
          ),
        );
      } else {
        await into(attendanceRecords).insert(
          AttendanceRecordsCompanion.insert(
            id: id,
            spaceId: spaceId,
            groupId: Value(groupId),
            subjectId: subjectId,
            date: date,
            status: status,
            notes: Value(notes),
            recordedBy: recordedBy,
            recordedAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }

  /// Bulk-insert attendance rows for all subjects in a group on a
  /// single date — one transaction, one commit. Used by Mark all
  /// present to avoid N round-trips when filling a roomful of kids.
  /// Returns the list of subjectIds that actually had a row inserted
  /// (skipping any subject already on record for that date).
  ///
  /// Records are inserted with the given [status]; existing rows are
  /// left alone so an "absent" isn't accidentally overwritten.
  Future<List<String>> bulkInsertAttendance({
    required String spaceId,
    required String groupId,
    required String date,
    required String status,
    required String recordedBy,
    required List<({String id, String subjectId})> entries,
  }) async {
    if (entries.isEmpty) return const [];
    final now = DateTime.now().toUtc().toIso8601String();
    final inserted = <String>[];
    await transaction(() async {
      // One query for the whole batch — find which subjects already
      // have a row today.
      final subjectIds = entries.map((e) => e.subjectId).toList();
      final existingRows = await (select(attendanceRecords)
            ..where(
              (a) => a.date.equals(date) & a.subjectId.isIn(subjectIds),
            ))
          .get();
      final alreadyHave =
          existingRows.map((r) => r.subjectId).toSet();

      for (final entry in entries) {
        if (alreadyHave.contains(entry.subjectId)) continue;
        await into(attendanceRecords).insert(
          AttendanceRecordsCompanion.insert(
            id: entry.id,
            spaceId: spaceId,
            groupId: Value(groupId),
            subjectId: entry.subjectId,
            date: date,
            status: status,
            recordedBy: recordedBy,
            recordedAt: now,
            updatedAt: now,
          ),
        );
        inserted.add(entry.subjectId);
      }
    });
    return inserted;
  }

  /// Delete attendance rows for the given (subject, date) pairs. Used
  /// by the "Mark all present → Undo" snack — reverts the rows we just
  /// wrote rather than overwriting them with another status.
  Future<void> deleteAttendanceForSubjectsOnDate({
    required List<String> subjectIds,
    required String date,
  }) async {
    if (subjectIds.isEmpty) return;
    await (delete(attendanceRecords)
          ..where(
            (a) => a.date.equals(date) & a.subjectId.isIn(subjectIds),
          ))
        .go();
  }

  // -- Group members (staff assignment) -------------------------------------

  /// All assignment rows for a member — used to derive which classrooms
  /// they're scoped to. Directors don't need this; their groupsProvider
  /// returns the full space.
  Stream<List<GroupMember>> watchAssignmentsForMember(String memberId) {
    return (select(groupMembers)..where((g) => g.memberId.equals(memberId)))
        .watch();
  }

  /// All members assigned to a classroom. Used by the Group detail
  /// screen's staff list.
  Stream<List<GroupMember>> watchAssignmentsForGroup(String groupId) {
    return (select(groupMembers)..where((g) => g.groupId.equals(groupId)))
        .watch();
  }

  /// Idempotent assign. Inserts a row if the (group, member) pair
  /// isn't already there; otherwise no-op.
  Future<void> assignMemberToGroup({
    required String groupId,
    required String memberId,
    required String spaceId,
    String? roleInGroup,
  }) async {
    final existing = await (select(groupMembers)
          ..where(
            (g) => g.groupId.equals(groupId) & g.memberId.equals(memberId),
          ))
        .getSingleOrNull();
    if (existing != null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    await into(groupMembers).insert(
      GroupMembersCompanion.insert(
        id: const Uuid().v4(),
        groupId: groupId,
        memberId: memberId,
        spaceId: spaceId,
        roleInGroup:
            roleInGroup == null ? const Value.absent() : Value(roleInGroup),
        assignedAt: now,
      ),
    );
  }

  /// Idempotent unassign.
  Future<void> unassignMemberFromGroup({
    required String groupId,
    required String memberId,
  }) async {
    await (delete(groupMembers)
          ..where(
            (g) => g.groupId.equals(groupId) & g.memberId.equals(memberId),
          ))
        .go();
  }

  // -- Invites --------------------------------------------------------------

  /// Watch all un-accepted invites for a space. Expired ones are kept
  /// in the list intentionally — the UI labels them "Expired" so the
  /// director can revoke them. (If we filtered by `expires_at > now()`
  /// here, the predicate would be captured at subscription time and
  /// not re-evaluate as the wall clock moves; rows would stick around
  /// past their expiry until the stream is re-subscribed.)
  Stream<List<Invite>> watchPendingInvitesInSpace(String spaceId) {
    return (select(invites)
          ..where(
            (i) => i.spaceId.equals(spaceId) & i.acceptedAt.isNull(),
          )
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
        .watch();
  }

  Future<void> createInvite({
    required String id,
    required String spaceId,
    required String role,
    String? email,
    String? code,
    String? createdBy,
    String? expiresAt,
    String? subjectId,
    String capabilitiesJson = '{}',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(invites).insert(
      InvitesCompanion.insert(
        id: id,
        spaceId: spaceId,
        role: role,
        email: email == null ? const Value.absent() : Value(email),
        code: code == null ? const Value.absent() : Value(code),
        subjectId:
            subjectId == null ? const Value.absent() : Value(subjectId),
        createdBy: createdBy == null ? const Value.absent() : Value(createdBy),
        expiresAt: expiresAt == null ? const Value.absent() : Value(expiresAt),
        capabilities: capabilitiesJson,
        createdAt: now,
      ),
    );
  }

  /// "Revoke" = delete the row. The unique constraint on `code` releases
  /// the code for future reuse; the recipient (if any) won't see it
  /// because their sync stream filters to their own space.
  Future<void> revokeInvite(String id) async {
    await (delete(invites)..where((i) => i.id.equals(id))).go();
  }

  // -- Entries (observations / meals / naps / diapers / ...) ---------------

  /// All entries for a classroom of a given kind, newest first. The
  /// observations screen uses kind='observation'.
  Stream<List<Entry>> watchEntriesForGroup({
    required String groupId,
    required String kind,
    int limit = 100,
  }) {
    return (select(entries)
          ..where((e) => e.groupId.equals(groupId) & e.kind.equals(kind))
          ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)])
          ..limit(limit))
        .watch();
  }

  /// All entries for a subject, newest first. Powers a future Subject
  /// detail screen and the "recent observations" surface.
  Stream<List<Entry>> watchEntriesForSubject({
    required String subjectId,
    String? kind,
    int limit = 50,
  }) {
    final query = select(entries)
      ..where((e) {
        final base = e.subjectId.equals(subjectId);
        return kind == null ? base : base & e.kind.equals(kind);
      })
      ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)])
      ..limit(limit);
    return query.watch();
  }

  /// Every entry of a kind across the whole space, newest first.
  /// Powers the top-level `/observations` index. Teachers see only
  /// what's visible to them — the viewer-side filtering happens in
  /// the provider that wraps this stream, since the DB doesn't know
  /// about classroom assignments.
  Stream<List<Entry>> watchEntriesInSpace({
    required String spaceId,
    required String kind,
    int limit = 200,
  }) {
    return (select(entries)
          ..where((e) => e.spaceId.equals(spaceId) & e.kind.equals(kind))
          ..orderBy([(e) => OrderingTerm.desc(e.recordedAt)])
          ..limit(limit))
        .watch();
  }

  Future<void> createEntry({
    required String id,
    required String spaceId,
    required String kind,
    required String recordedBy,
    String? groupId,
    String? subjectId,
    String? body,
    String? photoUrl,
    String detailsJson = '{}',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(entries).insert(
      EntriesCompanion.insert(
        id: id,
        spaceId: spaceId,
        kind: kind,
        groupId: groupId == null ? const Value.absent() : Value(groupId),
        subjectId:
            subjectId == null ? const Value.absent() : Value(subjectId),
        body: body == null ? const Value.absent() : Value(body),
        photoUrl: photoUrl == null ? const Value.absent() : Value(photoUrl),
        details: detailsJson,
        recordedBy: recordedBy,
        recordedAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Update an entry's text. The other fields are effectively
  /// immutable here — kind / subject / group don't move once the row
  /// is created. Use [updateEntryPhotos] to change attached photos.
  Future<void> updateEntry({
    required String id,
    String? body,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(entries)..where((e) => e.id.equals(id))).write(
      EntriesCompanion(
        body: body == null ? const Value.absent() : Value(body),
        updatedAt: Value(now),
      ),
    );
  }

  /// Replace an entry's attached photos. Pass `photoUrl: null` and the
  /// serialized `detailsJson` that has no `photos` key to clear them.
  /// Both fields are always written (Value(...)), not Value.absent(),
  /// because callers explicitly stage the full new state.
  Future<void> updateEntryPhotos({
    required String id,
    required String? photoUrl,
    required String detailsJson,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(entries)..where((e) => e.id.equals(id))).write(
      EntriesCompanion(
        photoUrl: Value(photoUrl),
        details: Value(detailsJson),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteEntry(String id) async {
    await (delete(entries)..where((e) => e.id.equals(id))).go();
  }

  // -- Vehicles + vehicle_logs ---------------------------------------------

  Stream<List<Vehicle>> watchVehiclesInSpace(String spaceId) {
    return (select(vehicles)
          ..where((v) => v.spaceId.equals(spaceId))
          ..orderBy([(v) => OrderingTerm(expression: v.name)]))
        .watch();
  }

  Stream<Vehicle?> watchVehicle(String id) {
    return (select(vehicles)..where((v) => v.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Vehicle?> findVehicleById(String id) {
    return (select(vehicles)..where((v) => v.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> createVehicle({
    required String id,
    required String spaceId,
    required String name,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? color,
    String? notes,
    String capabilitiesJson = '{}',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(vehicles).insert(
      VehiclesCompanion.insert(
        id: id,
        spaceId: spaceId,
        name: name,
        make: Value(make),
        model: Value(model),
        year: Value(year),
        licensePlate: Value(licensePlate),
        color: Value(color),
        notes: Value(notes),
        capabilities: capabilitiesJson,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateVehicle({
    required String id,
    String? name,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? color,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(vehicles)..where((v) => v.id.equals(id))).write(
      VehiclesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        make: make == null ? const Value.absent() : Value(make),
        model: model == null ? const Value.absent() : Value(model),
        year: year == null ? const Value.absent() : Value(year),
        licensePlate: licensePlate == null
            ? const Value.absent()
            : Value(licensePlate),
        color: color == null ? const Value.absent() : Value(color),
        notes: notes == null ? const Value.absent() : Value(notes),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateVehicleCapabilities(String id, String capsJson) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(vehicles)..where((v) => v.id.equals(id))).write(
      VehiclesCompanion(
        capabilities: Value(capsJson),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateVehiclePhotoUrl(String id, String? url) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(vehicles)..where((v) => v.id.equals(id))).write(
      VehiclesCompanion(
        photoUrl: Value(url),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteVehicle(String id) async {
    await (delete(vehicles)..where((v) => v.id.equals(id))).go();
  }

  Stream<List<VehicleLog>> watchLogsForVehicle(String vehicleId) {
    return (select(vehicleLogs)
          ..where((l) => l.vehicleId.equals(vehicleId))
          ..orderBy([
            (l) => OrderingTerm(
                  expression: l.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  /// Latest log row for a vehicle. The vehicle's current state is
  /// "out" if this is a checkout, "in" otherwise (or no row → never
  /// driven).
  Stream<VehicleLog?> watchLatestLogForVehicle(String vehicleId) {
    return (select(vehicleLogs)
          ..where((l) => l.vehicleId.equals(vehicleId))
          ..orderBy([
            (l) => OrderingTerm(
                  expression: l.createdAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> createVehicleLog({
    required String id,
    required String spaceId,
    required String vehicleId,
    required String kind,
    required String driverMemberId,
    int? odometer,
    String? fuelLevel,
    String itemsJson = '{}',
    String? notes,
    String? bodyDamageNotes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(vehicleLogs).insert(
      VehicleLogsCompanion.insert(
        id: id,
        spaceId: spaceId,
        vehicleId: vehicleId,
        kind: kind,
        driverMemberId: driverMemberId,
        odometer: Value(odometer),
        fuelLevel: Value(fuelLevel),
        items: itemsJson,
        notes: Value(notes),
        bodyDamageNotes: Value(bodyDamageNotes),
        createdAt: now,
      ),
    );
  }

  // -- Guardians ------------------------------------------------------------

  /// All guardians attached to a specific subject. Joined via the
  /// subject_guardians link table.
  Stream<List<Guardian>> watchGuardiansForSubject(String subjectId) {
    final query = select(guardians).join([
      innerJoin(
        subjectGuardians,
        subjectGuardians.guardianId.equalsExp(guardians.id),
      ),
    ])
      ..where(subjectGuardians.subjectId.equals(subjectId))
      ..orderBy([
        OrderingTerm(expression: subjectGuardians.isPrimary, mode: OrderingMode.desc),
        OrderingTerm(expression: guardians.name),
      ]);
    return query.watch().map((rows) =>
        rows.map((r) => r.readTable(guardians)).toList());
  }

  /// Add a new guardian and attach them to a subject in one transaction.
  /// Used by the "Add guardian" affordance on subject detail.
  Future<void> createGuardianForSubject({
    required String guardianId,
    required String subjectId,
    required String spaceId,
    required String name,
    String? relationship,
    String? phone,
    String? email,
    bool isPrimary = false,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await into(guardians).insert(
        GuardiansCompanion.insert(
          id: guardianId,
          spaceId: spaceId,
          name: name,
          relationship:
              relationship == null ? const Value.absent() : Value(relationship),
          phone: phone == null ? const Value.absent() : Value(phone),
          email: email == null ? const Value.absent() : Value(email),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await into(subjectGuardians).insert(
        SubjectGuardiansCompanion.insert(
          id: const Uuid().v4(),
          subjectId: subjectId,
          guardianId: guardianId,
          spaceId: spaceId,
          isPrimary: Value(isPrimary ? 1 : 0),
          createdAt: now,
        ),
      );
    });
  }

  /// Unlink a guardian from a subject. The guardian row stays — they
  /// might still be attached to a sibling, or future re-add.
  Future<void> unlinkGuardianFromSubject({
    required String guardianId,
    required String subjectId,
  }) async {
    await (delete(subjectGuardians)
          ..where(
            (sg) =>
                sg.guardianId.equals(guardianId) &
                sg.subjectId.equals(subjectId),
          ))
        .go();
  }

  /// Find the guardian row that an authenticated user resolves to.
  /// Returns null when the signed-in user isn't linked to any guardian
  /// — i.e., they're staff or not yet onboarded.
  Stream<Guardian?> watchGuardianForUser(String authUserId) {
    return (select(guardians)..where((g) => g.userId.equals(authUserId)))
        .watchSingleOrNull();
  }

  /// Subjects this guardian is linked to via subject_guardians. The
  /// family-side lens reads ONLY these subjects.
  Stream<List<Subject>> watchChildrenForGuardian(String guardianId) {
    final query = select(subjects).join([
      innerJoin(
        subjectGuardians,
        subjectGuardians.subjectId.equalsExp(subjects.id),
      ),
    ])
      ..where(subjectGuardians.guardianId.equals(guardianId))
      ..orderBy([
        OrderingTerm(expression: subjects.firstName),
        OrderingTerm(expression: subjects.lastName),
      ]);
    return query.watch().map((rows) =>
        rows.map((r) => r.readTable(subjects)).toList());
  }
}
