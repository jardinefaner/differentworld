import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the **Spellbook** home is switched on (docs/VISION.md 2026-06-19 — a
/// magic-framed surface that gathers the day's ritual + the week's project +
/// the unfolding story into one place the room opens each day).
///
/// **Defaults to OFF.** It's an aggregator over surfaces that already exist
/// (the Daily, the weekly world/project, the journey); a director opts in from
/// Settings → Preferences. Reversible, same contract as `heroesEnabledProvider`.
final spellbookEnabledProvider =
    AsyncNotifierProvider<SpellbookEnabledNotifier, bool>(
      SpellbookEnabledNotifier.new,
    );

class SpellbookEnabledNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.spellbook_enabled';

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
