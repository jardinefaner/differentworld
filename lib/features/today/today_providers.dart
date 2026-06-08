import 'dart:convert';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/foundation.dart';
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

  /// Children physically in the building today: present or late (arrived,
  /// just late). Excludes absent / excused / early-pickup / unmarked.
  int get inBuildingCount =>
      (counts[AttendanceStatus.present] ?? 0) +
      (counts[AttendanceStatus.late] ?? 0);

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

  /// The coarse phase for [now] using the afterschool default windows. This is
  /// the fallback used while the program's configured windows are still
  /// loading; the live source is [dayPhaseProvider] (which honours the
  /// program's [DayPhaseWindows]).
  static DayPhase fromClock(DateTime now) =>
      DayPhaseWindows.afterschool.phaseAt(now);
}

/// The clock boundaries that split a program's day into [DayPhase]s — minutes
/// from midnight for the start of arrival, program, pickup, and closed. The
/// afterschool defaults assume a 2:30–6:30 window; a camp or full-day program
/// overrides them (stored on the Space caps), so the whole "RIGHT NOW" lead
/// system retimes instead of assuming afterschool hours all day.
@immutable
class DayPhaseWindows {
  const DayPhaseWindows({
    required this.arrivalStart,
    required this.programStart,
    required this.pickupStart,
    required this.closedStart,
  });

  /// All four are minutes from midnight, strictly ascending.
  final int arrivalStart;
  final int programStart;
  final int pickupStart;
  final int closedStart;

  /// The historical hardcoded windows: arrival 2:30p · program 3:45p ·
  /// pickup 4:45p · closed 6:30p.
  static const afterschool = DayPhaseWindows(
    arrivalStart: 14 * 60 + 30,
    programStart: 15 * 60 + 45,
    pickupStart: 16 * 60 + 45,
    closedStart: 18 * 60 + 30,
  );

  DayPhase phaseAt(DateTime now) {
    final m = now.hour * 60 + now.minute;
    if (m < arrivalStart) return DayPhase.prep;
    if (m < programStart) return DayPhase.arrival;
    if (m < pickupStart) return DayPhase.program;
    if (m < closedStart) return DayPhase.pickup;
    return DayPhase.closed;
  }

  DayPhaseWindows copyWith({
    int? arrivalStart,
    int? programStart,
    int? pickupStart,
    int? closedStart,
  }) => DayPhaseWindows(
    arrivalStart: arrivalStart ?? this.arrivalStart,
    programStart: programStart ?? this.programStart,
    pickupStart: pickupStart ?? this.pickupStart,
    closedStart: closedStart ?? this.closedStart,
  );

  Map<String, dynamic> toJson() => {
    'arrival': arrivalStart,
    'program': programStart,
    'pickup': pickupStart,
    'closed': closedStart,
  };
}

/// Decode the caps JSON → windows. Anything invalid falls back to the
/// afterschool defaults, and the four boundaries are forced strictly ascending
/// (each at least a minute after the previous) so a misconfigured cap can never
/// produce an unreachable phase.
DayPhaseWindows decodePhaseWindows(String? raw) {
  if (raw == null || raw.isEmpty) return DayPhaseWindows.afterschool;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return DayPhaseWindows.afterschool;
    const def = DayPhaseWindows.afterschool;
    int pick(String k, int fallback) {
      final v = decoded[k];
      return v is num ? v.toInt().clamp(0, 24 * 60 - 1) : fallback;
    }

    final a = pick('arrival', def.arrivalStart);
    var p = pick('program', def.programStart);
    var u = pick('pickup', def.pickupStart);
    var c = pick('closed', def.closedStart);
    if (p <= a) p = a + 1;
    if (u <= p) u = p + 1;
    if (c <= u) c = u + 1;
    return DayPhaseWindows(
      arrivalStart: a,
      programStart: p,
      pickupStart: u,
      closedStart: c,
    );
  } on FormatException {
    return DayPhaseWindows.afterschool;
  }
}

String encodePhaseWindows(DayPhaseWindows w) => jsonEncode(w.toJson());

/// The program's live day-phase windows, off the Space caps (offline-first,
/// `.select`-gated). Defaults to afterschool until a director retimes them.
final dayPhaseWindowsProvider = Provider<DayPhaseWindows>((ref) {
  final raw = ref.watch(
    currentSpaceProvider.select(
      (s) => s.value?.caps.getString(SpaceCaps.phaseWindows),
    ),
  );
  return decodePhaseWindows(raw);
});

/// Director-only write of the day-phase windows (wholesale replace).
class DayPhaseActions {
  DayPhaseActions(this._ref);
  final Ref _ref;

  Future<void> setWindows(String spaceId, DayPhaseWindows windows) {
    return _ref
        .read(spaceCapActionsProvider)
        .setStringCap(
          spaceId,
          SpaceCaps.phaseWindows,
          encodePhaseWindows(windows),
        );
  }
}

final dayPhaseActionsProvider = Provider<DayPhaseActions>(DayPhaseActions.new);

/// Cross-cohort arrival snapshot for today: how many children are in the
/// building (present/late) vs the total roster the viewer can see. Drives
/// the "12 of 18 in" arrival progress on Today (docs/WORKFLOWS.md, the
/// arrival-rush opportunity). Derived purely from attendance — accurate
/// regardless of whether the new pickup board is adopted.
class ArrivalProgress {
  const ArrivalProgress({required this.inBuilding, required this.total});

  final int inBuilding;
  final int total;

  int get stillOut => (total - inBuilding).clamp(0, total);
  bool get allIn => total > 0 && inBuilding >= total;
}

/// Folds every visible cohort's [GroupDayState] into one arrival count.
/// A cohort whose attendance stream hasn't delivered yet is skipped (it
/// fills in on its next emit), same progressive shape as the pickup board.
final arrivalProgressProvider = Provider<AsyncValue<ArrivalProgress>>((ref) {
  final groupsAsync = ref.watch(groupsProvider);
  final groups = groupsAsync.value;
  if (groups == null) {
    return groupsAsync.hasError
        ? AsyncError(groupsAsync.error!, groupsAsync.stackTrace!)
        : const AsyncLoading();
  }
  var inBuilding = 0;
  var total = 0;
  for (final g in groups) {
    final state = ref.watch(groupDayStateProvider(g)).value;
    if (state == null) continue;
    inBuilding += state.inBuildingCount;
    total += state.totalSubjects;
  }
  return AsyncData(ArrivalProgress(inBuilding: inBuilding, total: total));
});

/// Live day phase — re-emits when the wall clock crosses a phase
/// boundary so Today can lead with the right "Right now" card without a
/// manual refresh. Emits immediately, then re-checks every minute;
/// `.distinct()` means the card only rebuilds when the phase actually
/// changes (not once a minute).
final dayPhaseProvider = StreamProvider<DayPhase>((ref) async* {
  // Use the program's configured windows (camps/full-day retime the day);
  // a window change re-runs this stream.
  final windows = ref.watch(dayPhaseWindowsProvider);
  var last = windows.phaseAt(DateTime.now());
  yield last;
  // Re-check each wall-clock minute, aligning the first tick to the next :00
  // so a boundary crossing is caught within ~1s — not up to 59s late, which
  // matters now that crossing a phase shows a one-time announcement. Emits
  // only when the phase actually changes (the old `.distinct()` behaviour).
  while (true) {
    final now = DateTime.now();
    // Sleep to just past the next wall-clock minute (millisecond-accurate, so
    // a clean :00 second waits a full minute rather than skipping or busy-
    // looping). Phase boundaries are minute-aligned, so checking each :00
    // catches every crossing within ~1s.
    final msToNextMinute = (60 - now.second) * 1000 - now.millisecond;
    await Future<void>.delayed(Duration(milliseconds: msToNextMinute));
    final next = windows.phaseAt(DateTime.now());
    if (next != last) {
      last = next;
      yield next;
    }
  }
});
