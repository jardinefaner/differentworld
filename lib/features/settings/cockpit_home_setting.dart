import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the clock-driven cockpit (`/now`) is the HOME surface instead of
/// Today (docs/COCKPIT.md slice 4 — the promotion path).
///
/// **Defaults to ON (the spine).** A signed-in staffer lands on the advancing
/// cockpit — it shows what's now AND what's next, walking them through the day
/// rather than the passive dashboard naming the moment (docs/WORKFLOWS.md seam
/// 4). Today is never lost: it stays reachable at `/today` (the cockpit's "More
/// places") and from the omnibox, and a director who prefers the dashboard
/// turns this OFF in Settings → Preferences (reversible — "ship new layouts as
/// toggles"). Guardians are unaffected — `_Home` resolves their family path
/// before this is ever read.
final cockpitAsHomeProvider =
    AsyncNotifierProvider<CockpitAsHomeNotifier, bool>(
      CockpitAsHomeNotifier.new,
    );

class CockpitAsHomeNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.cockpit_as_home';

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
