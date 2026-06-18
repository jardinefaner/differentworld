import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the wide-screen schedule uses the **time-aligned grid** (cohorts ×
/// time, blocks span the shared axis) instead of the default cohorts-as-columns
/// matrix (docs/GRID.md — the schedule consumer).
///
/// **Defaults to OFF.** The column matrix stays the wide-screen default until a
/// director opts in; flipping back is one tap in Settings → Preferences, and
/// phones keep the per-cohort tabs either way. Only takes effect at matrix
/// widths (≥ 720dp); narrow windows always fall back to tabs.
final scheduleTimeGridProvider =
    AsyncNotifierProvider<ScheduleTimeGridNotifier, bool>(
      ScheduleTimeGridNotifier.new,
    );

class ScheduleTimeGridNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.schedule_time_grid';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKey) ?? false;
  }

  Future<void> set({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);
    state = AsyncData(value);
  }
}
