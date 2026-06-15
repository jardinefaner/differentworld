import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the clock-driven cockpit (`/now`) is the HOME surface instead of
/// Today (docs/COCKPIT.md slice 4 — the promotion path).
///
/// **Defaults to OFF.** Today stays home until a director opts in; the cockpit
/// is always reachable via its `/now` route + the omnibox regardless, and when
/// ON, Today is demoted to a curiosity destination (`/today`), never lost.
/// Reversible from Settings → Preferences.
final cockpitAsHomeProvider =
    AsyncNotifierProvider<CockpitAsHomeNotifier, bool>(
  CockpitAsHomeNotifier.new,
);

class CockpitAsHomeNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.cockpit_as_home';

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
