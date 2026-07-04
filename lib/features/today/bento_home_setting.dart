import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the **bento dashboard** is the home surface instead of the classic
/// Today scroll (docs/PRIMITIVES.md — the grid-navigation experiment).
///
/// **Defaults to OFF.** Today stays home until a director opts in; flipping it
/// back is one tap in Settings → Preferences, so trying the bento costs
/// nothing and reverting loses nothing. The classic Today is never deleted —
/// it's the same providers, re-laid-out.
///
/// Precedence: the cockpit (`cockpitAsHomeProvider`) wins if both are on — it's
/// the established promotion path. Bento is the alternate when the cockpit is
/// off. See `_SignedInHome` in router.dart.
final bentoHomeProvider = AsyncNotifierProvider<BentoHomeNotifier, bool>(
  BentoHomeNotifier.new,
);

class BentoHomeNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.bento_home';

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
