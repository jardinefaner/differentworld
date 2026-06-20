import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS a direct dep in pubspec.yaml; the analyzer sometimes
// warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the per-child **daily hub** (`/subjects/:id/day`) renders as a BENTO
/// grid rather than the stacked list — the same content (identity, today's
/// words, mood, missions, the room's day) re-laid-out into modular tiles that
/// spread on a tablet. The words + mood tiles stay INTERACTIVE (their tap
/// targets live inside the tile); the gallery stays full-width below.
///
/// **Defaults to OFF.** Opt in from Settings → Preferences. Reversible by design
/// (the "ship new layouts as toggles" rule — re-layout existing providers, don't
/// rebuild data), same contract as `programHubBentoProvider`.
final childDayBentoProvider =
    AsyncNotifierProvider<ChildDayBentoNotifier, bool>(
      ChildDayBentoNotifier.new,
    );

class ChildDayBentoNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.child_day_bento';

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
