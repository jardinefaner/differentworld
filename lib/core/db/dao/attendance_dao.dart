import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'attendance_dao.g.dart';

/// Daily attendance roster. The fast path for the per-group, per-date
/// "who's here?" question. Bulk-insert keeps "Mark all present" to one
/// transaction regardless of roster size.
@DriftAccessor(tables: [AttendanceRecords])
class AttendanceDao extends DatabaseAccessor<AppDatabase>
    with _$AttendanceDaoMixin {
  AttendanceDao(super.attachedDatabase);

  Stream<List<AttendanceRecord>> watchForGroupOnDate(
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
  Future<void> upsert({
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
  /// single date — one transaction, one commit. Used by "Mark all
  /// present" to avoid N round-trips when filling a roomful of kids.
  /// Returns the list of subjectIds that actually had a row inserted
  /// (skipping any subject already on record for that date).
  ///
  /// Records are inserted with the given [status]; existing rows are
  /// left alone so an "absent" isn't accidentally overwritten.
  Future<List<String>> bulkInsert({
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
      final alreadyHave = existingRows.map((r) => r.subjectId).toSet();

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
  Future<void> deleteForSubjectsOnDate({
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
}
