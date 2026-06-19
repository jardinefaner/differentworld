import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS a direct dep in pubspec.yaml; the analyzer sometimes
// warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the **program hub** (`/program`) renders as a BENTO grid
/// (docs/GRID.md candidate) rather than the stacked list — the same content
/// (the season world, today, the journey, cast, and each child's arc)
/// re-laid-out into modular tiles that spread on a tablet.
///
/// **Defaults to OFF.** Opt in from Settings → Preferences. Reversible by design
/// (the "ship new layouts as toggles" rule — re-layout existing providers, don't
/// rebuild data), same contract as `spellbookBentoProvider` / `bentoHomeProvider`.
final programHubBentoProvider =
    AsyncNotifierProvider<ProgramHubBentoNotifier, bool>(
      ProgramHubBentoNotifier.new,
    );

class ProgramHubBentoNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.program_hub_bento';

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
