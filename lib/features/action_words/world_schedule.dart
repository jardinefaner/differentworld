import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which week of the 10-week journey is live, given the program's start
/// date and today. Returns null when the journey hasn't started, hasn't
/// reached the start date yet, or has run past week 10. Pure + testable.
int? curriculumWeekFor(DateTime? start, DateTime now) {
  if (start == null) return null;
  final startDay = DateTime(start.year, start.month, start.day);
  final today = DateTime(now.year, now.month, now.day);
  if (today.isBefore(startDay)) return null;
  final week = today.difference(startDay).inDays ~/ 7 + 1;
  if (week < 1 || week > 10) return null;
  return week;
}

/// The date Week 1 begins for a given target [week] so that [now] lands in
/// it — used by "jump to week N" (we store a start date, not a week number,
/// so the journey keeps auto-advancing afterward).
DateTime startDateForWeek(int week, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: (week - 1) * 7));
}

/// The program's Week-1 start date (null = the journey isn't set up). Drives
/// the Book's week-by-week grouping of a child's moments.
final programStartDateProvider = Provider<DateTime?>((ref) {
  final raw = ref.watch(
    currentSpaceProvider
        .select((s) => s.value?.caps.getString(SpaceCaps.programStartDate)),
  );
  return raw == null ? null : DateTime.tryParse(raw);
});

/// The live curriculum week (1–10), derived from the program start date
/// cap. Null when the journey isn't set up / active.
final currentCurriculumWeekProvider = Provider<int?>((ref) {
  final raw = ref.watch(
    currentSpaceProvider
        .select((s) => s.value?.caps.getString(SpaceCaps.programStartDate)),
  );
  final start = raw == null ? null : DateTime.tryParse(raw);
  return curriculumWeekFor(start, DateTime.now());
});

/// The world the room is living in THIS week — the live [CurriculumWorld],
/// or null when the journey isn't active (or the catalog is still loading).
final currentWorldProvider = Provider<CurriculumWorld?>((ref) {
  final week = ref.watch(currentCurriculumWeekProvider);
  if (week == null) return null;
  final worlds = ref.watch(curriculumWorldsProvider).value;
  if (worlds == null) return null;
  for (final w in worlds) {
    if (w.week == week) return w;
  }
  return null;
});

/// Set / move / clear the 10-week journey. Stored as the program start date
/// on the Space's caps (optimistic, like every other cap write).
class WorldScheduleActions {
  WorldScheduleActions(this._ref);
  final Ref _ref;

  String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> setStartDate(String spaceId, DateTime date) {
    return _ref
        .read(spaceCapActionsProvider)
        .setStringCap(spaceId, SpaceCaps.programStartDate, _isoDate(date));
  }

  /// "We're on Week N now" — back-computes a start date so today is in week N.
  Future<void> jumpToWeek(String spaceId, int week) {
    return setStartDate(spaceId, startDateForWeek(week, DateTime.now()));
  }

  Future<void> clear(String spaceId) {
    return _ref
        .read(spaceCapActionsProvider)
        .setStringCap(spaceId, SpaceCaps.programStartDate, null);
  }
}

final worldScheduleActionsProvider =
    Provider<WorldScheduleActions>(WorldScheduleActions.new);
