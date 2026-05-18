import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// (groupId, isoDate) pair so a single provider can be keyed by both.
typedef AttendanceKey = ({String groupId, String date});

/// Live stream of all attendance records in a Group on a given day.
/// Stays in loading until the DB is open.
// ignore: specify_nonobvious_property_types
final attendanceForDayProvider =
    StreamProvider.family<List<AttendanceRecord>, AttendanceKey>(
  (ref, key) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchAttendanceForGroupOnDate(key.groupId, key.date);
  },
);

class AttendanceActions {
  AttendanceActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> setStatus({
    required String groupId,
    required String subjectId,
    required String date,
    required AttendanceStatus status,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final member = _ref.read(currentMemberProvider).value;
    final spaceId = member?.spaceId;
    final recordedBy = member?.id;
    if (spaceId == null || recordedBy == null) {
      throw StateError('No Space / signed-in Member.');
    }
    await db.upsertAttendance(
      id: _uuid.v4(),
      spaceId: spaceId,
      groupId: groupId,
      subjectId: subjectId,
      date: date,
      status: status.dbValue,
      recordedBy: recordedBy,
    );
  }

  /// Bulk-mark every Subject in a Group as `present` for a date — only
  /// writes for Subjects that don't yet have a record (skips already-
  /// recorded so an existing "absent" isn't overwritten).
  ///
  /// Goes through `db.bulkInsertAttendance` so all the inserts run in
  /// a single transaction — one commit, one PowerSync CRUD-batch per
  /// classroom regardless of roster size.
  ///
  /// Returns the list of subjectIds that were actually written, so the
  /// caller can offer an Undo for just those rows.
  Future<List<String>> markAllPresent({
    required String groupId,
    required String date,
    required List<String> subjectIds,
    required List<String> alreadyRecordedSubjectIds,
  }) async {
    if (subjectIds.isEmpty) return const [];
    final db = await _ref.read(appDatabaseProvider.future);
    final member = _ref.read(currentMemberProvider).value;
    final spaceId = member?.spaceId;
    final recordedBy = member?.id;
    if (spaceId == null || recordedBy == null) {
      throw StateError('No Space / signed-in Member.');
    }
    final alreadySet = alreadyRecordedSubjectIds.toSet();
    final entries = <({String id, String subjectId})>[];
    for (final subjectId in subjectIds) {
      if (alreadySet.contains(subjectId)) continue;
      entries.add((id: _uuid.v4(), subjectId: subjectId));
    }
    return db.bulkInsertAttendance(
      spaceId: spaceId,
      groupId: groupId,
      date: date,
      status: AttendanceStatus.present.dbValue,
      recordedBy: recordedBy,
      entries: entries,
    );
  }

  /// Undo a previous [markAllPresent] by deleting the attendance rows
  /// for the supplied subjects on a given date.
  Future<void> undoBulkPresent({
    required String date,
    required List<String> subjectIds,
  }) async {
    if (subjectIds.isEmpty) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.deleteAttendanceForSubjectsOnDate(
      subjectIds: subjectIds,
      date: date,
    );
  }

  /// Remove a single attendance record (driver: the new inline rows
  /// let the user re-tap the current status to clear it).
  Future<void> clearStatus({
    required String subjectId,
    required String date,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.deleteAttendanceForSubjectsOnDate(
      subjectIds: [subjectId],
      date: date,
    );
  }
}

final attendanceActionsProvider =
    Provider<AttendanceActions>(AttendanceActions.new);
