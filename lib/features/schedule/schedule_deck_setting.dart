import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether `/schedule` presents one cohort's day as a **deck** — each block a
/// full castable slide you swipe through (docs/VISION.md 2026-06-19: *"the app
/// creates slides that coordinate the room"*) — instead of the default
/// chronological list of block rows.
///
/// **Defaults to OFF.** The agenda list stays the default; the deck is the
/// opt-in "I'm running the day, one block at a time" present mode. Flipping
/// back is one tap in Settings → Preferences. Orthogonal to the wide-screen
/// time-grid (`scheduleTimeGridProvider`): the deck is the phone / single-
/// cohort present surface, the grid/matrix is the wide-screen planning glance.
final scheduleDeckProvider =
    AsyncNotifierProvider<ScheduleDeckNotifier, bool>(ScheduleDeckNotifier.new);

class ScheduleDeckNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.schedule_deck';

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

/// Whether the deck **follows the clock** — auto-advancing to the live block as
/// the day crosses block boundaries, so "what's needed currently" is always the
/// slide in front. **Defaults to ON.** When off, the deck opens on the live
/// block but stays where you swipe it. Only auto-jumps at a boundary (when the
/// live block actually changes), never mid-swipe, so it can't yank a slide out
/// from under you while you peek ahead.
final scheduleDeckFollowsNowProvider =
    AsyncNotifierProvider<ScheduleDeckFollowsNowNotifier, bool>(
      ScheduleDeckFollowsNowNotifier.new,
    );

class ScheduleDeckFollowsNowNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.schedule_deck_follow';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKey) ?? true;
  }

  Future<void> set({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);
    state = AsyncData(value);
  }
}
