import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// (classroomId, isoDate) pair so a single provider can be keyed by both.
typedef AttendanceKey = ({String classroomId, String date});

/// Live stream of all attendance records in a classroom on a given day.
/// Stays in loading until the DB is open.
// ignore: specify_nonobvious_property_types
final attendanceForDayProvider =
    StreamProvider.family<List<AttendanceRecord>, AttendanceKey>(
  (ref, key) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchAttendanceForClassroomOnDate(key.classroomId, key.date);
  },
);

class AttendanceActions {
  AttendanceActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> setStatus({
    required String classroomId,
    required String studentId,
    required String date,
    required AttendanceStatus status,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final profile = _ref.read(currentProfileProvider).value;
    final programId = profile?.programId;
    final recordedBy = profile?.id;
    if (programId == null || recordedBy == null) {
      throw StateError('No program / signed-in user.');
    }
    await db.upsertAttendance(
      id: _uuid.v4(),
      programId: programId,
      classroomId: classroomId,
      studentId: studentId,
      date: date,
      status: status.dbValue,
      recordedBy: recordedBy,
    );
  }

  /// Bulk-mark every student in a classroom as `present` for a date —
  /// only writes for students who don't yet have a record (skips ones
  /// already marked anything else so we don't overwrite an "absent").
  Future<void> markAllPresent({
    required String classroomId,
    required String date,
    required List<String> studentIds,
    required List<String> alreadyRecordedStudentIds,
  }) async {
    for (final studentId in studentIds) {
      if (alreadyRecordedStudentIds.contains(studentId)) continue;
      await setStatus(
        classroomId: classroomId,
        studentId: studentId,
        date: date,
        status: AttendanceStatus.present,
      );
    }
  }
}

final attendanceActionsProvider =
    Provider<AttendanceActions>(AttendanceActions.new);
