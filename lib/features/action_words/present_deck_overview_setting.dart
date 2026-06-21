import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS a direct dep in pubspec.yaml; the analyzer sometimes
// warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the two BeatPresenter decks — the journey (`/journey`) and the day
/// run (`/play-today`) — open as a tappable **deck overview** (a grid of beat
/// tiles you tap to present from THAT beat) instead of dropping straight into
/// the immersive slideshow.
///
/// **Defaults to OFF.** Opt in from Settings → Preferences. Reversible by
/// design (the "ship new layouts as toggles" rule — re-layout existing beats,
/// don't rebuild data), same contract as `programHubBentoProvider`. When off,
/// the decks keep their exact current immersive behaviour.
final presentDeckOverviewProvider =
    AsyncNotifierProvider<PresentDeckOverviewNotifier, bool>(
      PresentDeckOverviewNotifier.new,
    );

class PresentDeckOverviewNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.present_deck_overview';

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
