import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the **Heroes** activity is switched on (docs/VISION.md 2026-06-19 —
/// kids build a make-believe alter-ego that accumulates into a Hero card).
///
/// **Defaults to OFF.** Heroes is a new kid-facing creative surface; a director
/// opts in from Settings → Preferences, and flipping it back is one tap. While
/// off, the Brain Breaks deck card, the omnibox entries, and the `/heroes`
/// destination stay hidden — nothing in the staff flow changes. Reversible by
/// design, same contract as `bentoHomeProvider`.
final heroesEnabledProvider =
    AsyncNotifierProvider<HeroesEnabledNotifier, bool>(
      HeroesEnabledNotifier.new,
    );

class HeroesEnabledNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.heroes_enabled';

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
