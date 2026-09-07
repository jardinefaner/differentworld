import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether Today shows the **what-needs-you** list above everything else.
///
/// **Defaults to OFF**, like every layout alternative here: a director tries
/// it, and turning it back is one tap. Nothing is replaced — the list is an
/// addition at the top of the same view, so reverting loses nothing.
///
/// It is a preference rather than always-on because it changes the CHARACTER
/// of the home screen. A calm view that reports the day and a view that ranks
/// what is wrong are different products, and which one a program wants is not
/// something the app should decide for it.
final needsYouProvider = AsyncNotifierProvider<NeedsYouNotifier, bool>(
  NeedsYouNotifier.new,
);

class NeedsYouNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.needs_you';

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
