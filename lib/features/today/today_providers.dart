import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's date in the local timezone, formatted YYYY-MM-DD.
String todayIso() {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Per-Group day rollup: total subjects, status breakdown, count
/// unmarked. Lives as a plain immutable value object.
class GroupDayState {
  const GroupDayState({
    required this.group,
    required this.totalSubjects,
    required this.counts,
  });

  final Group group;
  final int totalSubjects;
  final Map<AttendanceStatus, int> counts;

  int get markedCount => counts.values.fold<int>(0, (a, b) => a + b);
  int get unmarked => totalSubjects - markedCount;
  bool get isComplete => totalSubjects > 0 && unmarked == 0;

  /// Late or absent count today. Drives the "flag" badge on the
  /// classroom card.
  int get flagCount =>
      (counts[AttendanceStatus.late] ?? 0) +
      (counts[AttendanceStatus.absent] ?? 0);

  bool get hasFlag => flagCount > 0;
}

/// Reactive day state for one Group on today's date.
///
/// Composes via Riverpod — when subjects or attendance records change,
/// this provider re-evaluates. Returns `AsyncValue<GroupDayState>` so
/// the consumer can render loading / error / data states.
// ignore: specify_nonobvious_property_types
final groupDayStateProvider =
    Provider.family<AsyncValue<GroupDayState>, Group>((ref, group) {
  final date = todayIso();
  final subjectsAsync = ref.watch(subjectsInGroupProvider(group.id));
  final recordsAsync = ref.watch(
    attendanceForDayProvider((groupId: group.id, date: date)),
  );

  if (subjectsAsync.hasError) {
    return AsyncError(subjectsAsync.error!, subjectsAsync.stackTrace!);
  }
  if (recordsAsync.hasError) {
    return AsyncError(recordsAsync.error!, recordsAsync.stackTrace!);
  }
  if (!subjectsAsync.hasValue || !recordsAsync.hasValue) {
    return const AsyncLoading();
  }

  final subjects = subjectsAsync.value!;
  final records = recordsAsync.value!;

  final counts = <AttendanceStatus, int>{};
  for (final r in records) {
    final s = AttendanceStatus.fromDb(r.status);
    if (s != null) counts[s] = (counts[s] ?? 0) + 1;
  }

  return AsyncData(GroupDayState(
    group: group,
    totalSubjects: subjects.length,
    counts: counts,
  ));
});

/// Human label for today's "good morning" / "good afternoon" / etc.
String greetingForTime(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}
