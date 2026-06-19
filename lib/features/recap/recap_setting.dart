import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the **daily parent recap** is switched on (docs/VISION.md
/// 2026-06-19 — "every day, what we learn from today is shared with parents").
///
/// **Defaults to OFF.** A director opts in from Settings → Preferences; while
/// off, the composer's deck card + omnibox entry stay hidden. Reversible by
/// design, same contract as `dailyEnabledProvider`.
final recapEnabledProvider = AsyncNotifierProvider<RecapEnabledNotifier, bool>(
  RecapEnabledNotifier.new,
);

class RecapEnabledNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.recap_enabled';

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
