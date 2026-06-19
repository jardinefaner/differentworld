import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether **What to do instead** is switched on (docs/VISION.md 2026-06-19 —
/// the room's calm, co-held reference of what to do per feeling + the
/// agreements).
///
/// **Defaults to OFF.** A director opts in from Settings → Preferences; while
/// off, the deck card + omnibox entry stay hidden. Reversible by design, same
/// contract as `heroesEnabledProvider`.
final calmEnabledProvider = AsyncNotifierProvider<CalmEnabledNotifier, bool>(
  CalmEnabledNotifier.new,
);

class CalmEnabledNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.calm_enabled';

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
