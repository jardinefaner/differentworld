import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the **Daily** ritual is switched on (docs/VISION.md 2026-06-19 — the
/// Question / Quote / Mission of the Day, each answered with a response that
/// flows into the child's Book).
///
/// **Defaults to OFF.** A director opts in from Settings → Preferences; while
/// off, the deck card + omnibox entry stay hidden. Reversible by design, same
/// contract as `heroesEnabledProvider`.
final dailyEnabledProvider = AsyncNotifierProvider<DailyEnabledNotifier, bool>(
  DailyEnabledNotifier.new,
);

class DailyEnabledNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.daily_enabled';

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
