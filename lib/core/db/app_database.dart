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

@DriftDatabase(
  tables: [Spaces, Members, Groups, Subjects, AttendanceRecords],
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
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(groups).insert(
      GroupsCompanion.insert(
        id: id,
        spaceId: spaceId,
        name: name,
        ageRange: Value(ageRange),
        color: Value(color),
        capabilities: '{}',
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
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(groups)..where((g) => g.id.equals(id))).write(
      GroupsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        ageRange: ageRange == null ? const Value.absent() : Value(ageRange),
        color: color == null ? const Value.absent() : Value(color),
        updatedAt: Value(now),
      ),
    );
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
}
