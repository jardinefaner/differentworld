import 'package:drift/drift.dart';
import 'package:drift_sqlite_async/drift_sqlite_async.dart';
// Both drift and powersync export a `Column` class — only import what we
// actually need from powersync to avoid the ambiguity.
import 'package:powersync/powersync.dart' show PowerSyncDatabase;

part 'app_database.g.dart';

// Drift mirrors of the tables PowerSync owns. We never let Drift migrate the
// schema — PowerSync's local SQLite was created from supabase/migrations/*
// via the sync engine. Drift is purely for typed reads/writes/streams.
//
// Column names are auto-derived snake_case from camelCase Dart fields
// (`displayName` ↔ `display_name`).

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get programId => text().nullable()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Programs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get slug => text().nullable()();
  TextColumn get settings => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Classrooms extends Table {
  TextColumn get id => text()();
  TextColumn get programId => text()();
  TextColumn get name => text()();
  TextColumn get ageRange => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Students extends Table {
  TextColumn get id => text()();
  TextColumn get programId => text()();
  TextColumn get classroomId => text().nullable()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get dob => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get allergies => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class AttendanceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get programId => text()();
  TextColumn get classroomId => text().nullable()();
  TextColumn get studentId => text()();
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
  tables: [Profiles, Programs, Classrooms, Students, AttendanceRecords],
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
        onUpgrade: (m, from, to) async {},
      );

  Stream<Profile?> watchProfile(String userId) {
    return (select(profiles)..where((p) => p.id.equals(userId)))
        .watchSingleOrNull();
  }

  /// Two writes in one transaction:
  ///   1. INSERT the new program row.
  ///   2. UPDATE the current user's profile to point at it AND promote
  ///      them to director (whoever creates the program becomes the
  ///      director — the RLS policies on classrooms/enrollments require
  ///      this role to write).
  /// PowerSync's CRUD queue picks both up and uploads to Supabase.
  Future<void> createProgramForUser({
    required String programId,
    required String programName,
    required String userId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await into(programs).insert(
        ProgramsCompanion.insert(
          id: programId,
          name: programName,
          settings: '{}',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await (update(profiles)..where((p) => p.id.equals(userId))).write(
        ProfilesCompanion(
          programId: Value(programId),
          role: const Value('director'),
          updatedAt: Value(now),
        ),
      );
    });
  }

  // -- Classrooms -----------------------------------------------------------

  Stream<List<Classroom>> watchClassroomsForProgram(String programId) {
    return (select(classrooms)
          ..where((c) => c.programId.equals(programId))
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch();
  }

  Future<void> createClassroom({
    required String id,
    required String programId,
    required String name,
    String? ageRange,
    String? color,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(classrooms).insert(
      ClassroomsCompanion.insert(
        id: id,
        programId: programId,
        name: name,
        ageRange: Value(ageRange),
        color: Value(color),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateClassroom({
    required String id,
    String? name,
    String? ageRange,
    String? color,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(classrooms)..where((c) => c.id.equals(id))).write(
      ClassroomsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        ageRange: ageRange == null ? const Value.absent() : Value(ageRange),
        color: color == null ? const Value.absent() : Value(color),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteClassroom(String id) async {
    await (delete(classrooms)..where((c) => c.id.equals(id))).go();
  }

  Stream<Classroom?> watchClassroom(String id) {
    return (select(classrooms)..where((c) => c.id.equals(id)))
        .watchSingleOrNull();
  }

  // -- Students -------------------------------------------------------------

  Stream<List<Student>> watchStudentsForClassroom(String classroomId) {
    return (select(students)
          ..where((s) => s.classroomId.equals(classroomId))
          ..orderBy([
            (s) => OrderingTerm(expression: s.firstName),
            (s) => OrderingTerm(expression: s.lastName),
          ]))
        .watch();
  }

  Future<void> createStudent({
    required String id,
    required String programId,
    required String classroomId,
    required String firstName,
    required String lastName,
    String? dob,
    String? allergies,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(students).insert(
      StudentsCompanion.insert(
        id: id,
        programId: programId,
        classroomId: Value(classroomId),
        firstName: firstName,
        lastName: lastName,
        dob: Value(dob),
        allergies: Value(allergies),
        notes: Value(notes),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateStudent({
    required String id,
    String? firstName,
    String? lastName,
    String? dob,
    String? allergies,
    String? notes,
    String? classroomId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(students)..where((s) => s.id.equals(id))).write(
      StudentsCompanion(
        firstName: firstName == null ? const Value.absent() : Value(firstName),
        lastName: lastName == null ? const Value.absent() : Value(lastName),
        dob: dob == null ? const Value.absent() : Value(dob),
        allergies:
            allergies == null ? const Value.absent() : Value(allergies),
        notes: notes == null ? const Value.absent() : Value(notes),
        classroomId:
            classroomId == null ? const Value.absent() : Value(classroomId),
        updatedAt: Value(now),
      ),
    );
  }

  // -- Attendance -----------------------------------------------------------

  Stream<List<AttendanceRecord>> watchAttendanceForClassroomOnDate(
    String classroomId,
    String date,
  ) {
    return (select(attendanceRecords)
          ..where(
            (a) => a.classroomId.equals(classroomId) & a.date.equals(date),
          ))
        .watch();
  }

  /// Insert-or-update an attendance row for a (student, date) pair.
  /// The schema enforces UNIQUE(student_id, date) — we look up first to
  /// preserve the original `id` so PowerSync syncs a stable PK rather than
  /// thrashing rows with new IDs.
  Future<void> upsertAttendance({
    required String id,
    required String programId,
    required String classroomId,
    required String studentId,
    required String date,
    required String status,
    required String recordedBy,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      final existing = await (select(attendanceRecords)
            ..where(
              (a) => a.studentId.equals(studentId) & a.date.equals(date),
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
            programId: programId,
            classroomId: Value(classroomId),
            studentId: studentId,
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
