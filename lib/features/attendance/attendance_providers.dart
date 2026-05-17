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
  Future<void> markAllPresent({
    required String groupId,
    required String date,
    required List<String> subjectIds,
    required List<String> alreadyRecordedSubjectIds,
  }) async {
    for (final subjectId in subjectIds) {
      if (alreadyRecordedSubjectIds.contains(subjectId)) continue;
      await setStatus(
        groupId: groupId,
        subjectId: subjectId,
        date: date,
        status: AttendanceStatus.present,
      );
    }
  }
}

final attendanceActionsProvider =
    Provider<AttendanceActions>(AttendanceActions.new);
