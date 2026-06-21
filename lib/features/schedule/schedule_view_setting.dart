import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the wide-screen schedule uses the **time-aligned grid** (cohorts ×
/// time, blocks span the shared axis) instead of the cohorts-as-columns matrix
/// (docs/GRID.md — the schedule consumer).
///
/// **Defaults to ON — the tablet-first planning surface.** On a tablet/desktop
/// (≥ 720dp) the time-aligned grid is the default day-planning view, so "who's
/// outside at 4:00" is a single horizontal read the moment a director opens the
/// schedule on an iPad. Opt OUT (back to cohort columns) in one tap from
/// Settings → Preferences. Phones are unaffected either way — narrow windows
/// always keep the per-cohort tabs.
final scheduleTimeGridProvider =
    AsyncNotifierProvider<ScheduleTimeGridNotifier, bool>(
      ScheduleTimeGridNotifier.new,
    );

class ScheduleTimeGridNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.schedule_time_grid';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    // Default ON: the matrix is the tablet-first wide-screen view. A director
    // who prefers cohort columns has their explicit `false` honoured.
    return prefs.getBool(_kKey) ?? true;
  }

  Future<void> set({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);
    state = AsyncData(value);
  }
}
