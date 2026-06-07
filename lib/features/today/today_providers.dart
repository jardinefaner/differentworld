import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's date in the local timezone, formatted YYYY-MM-DD.
String todayIso() => todayKey();

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

/// The afterschool day's coarse phase, derived from the wall clock.
///
/// The default windows target an ages 4–12 **afterschool** program (the
/// primary product context): a quiet open, an arrival rush, program
/// blocks, a long staggered pickup, a closeout. These are *defaults*;
/// docs/WORKFLOWS.md gap #1 calls for making them program-configurable
/// later. v1 leads the Today screen with the right surface; it does NOT
/// add a data layer.
enum DayPhase {
  /// Before the rush — getting ready / planning the day.
  prep,

  /// Kids checking in as they arrive.
  arrival,

  /// Program blocks running.
  program,

  /// Dismissal — staggered pickup.
  pickup,

  /// After hours — the program day is over.
  closed;

  /// The coarse phase for [now], using afterschool default windows.
  ///
  /// Windows (local time): prep `< 2:30p` · arrival `2:30–3:45p` ·
  /// program `3:45–4:45p` · pickup `4:45–6:30p` · closed `≥ 6:30p`.
  static DayPhase fromClock(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    if (minutes < 14 * 60 + 30) return DayPhase.prep; // < 2:30p
    if (minutes < 15 * 60 + 45) return DayPhase.arrival; // 2:30–3:45p
    if (minutes < 16 * 60 + 45) return DayPhase.program; // 3:45–4:45p
    if (minutes < 18 * 60 + 30) return DayPhase.pickup; // 4:45–6:30p
    return DayPhase.closed; // ≥ 6:30p
  }
}

/// Live day phase — re-emits when the wall clock crosses a phase
/// boundary so Today can lead with the right "Right now" card without a
/// manual refresh. Emits immediately, then re-checks every minute;
/// `.distinct()` means the card only rebuilds when the phase actually
/// changes (not once a minute).
final dayPhaseProvider = StreamProvider<DayPhase>((ref) async* {
  yield DayPhase.fromClock(DateTime.now());
  yield* Stream.periodic(
    const Duration(minutes: 1),
    (_) => DayPhase.fromClock(DateTime.now()),
  ).distinct();
});
