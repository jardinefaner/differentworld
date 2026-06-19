import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the **Routines** view is switched on (docs/VISION.md 2026-06-19 —
/// the kid-legible read of the day: "what do we do at 9?").
///
/// **Defaults to OFF.** Routines re-skins the existing staff schedule for the
/// room; a director opts in from Settings → Preferences, and flipping it back
/// is one tap. While off, the deck card + omnibox entry stay hidden and the
/// staff schedule is untouched. Reversible by design, same contract as
/// `heroesEnabledProvider`.
final routinesEnabledProvider =
    AsyncNotifierProvider<RoutinesEnabledNotifier, bool>(
      RoutinesEnabledNotifier.new,
    );

class RoutinesEnabledNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.routines_enabled';

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
