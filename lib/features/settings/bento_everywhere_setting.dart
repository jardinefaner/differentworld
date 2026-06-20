import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS a direct dep in pubspec.yaml; the analyzer sometimes
// warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// The **global "Bento everywhere"** switch — one toggle that opts the WHOLE app
/// into the bento / Calm tile layout, instead of flipping each screen's own
/// switch. Every screen that has a bento variant shows it when EITHER this is on
/// OR its per-screen toggle is on (see [bentoEnabled]).
///
/// **Defaults to OFF.** Opt in from Settings → Preferences. Reversible by design
/// (the "ship new layouts as toggles" rule) — re-layout existing providers, no
/// data rebuilt. The user's call: because it's reversible, the bento language
/// can spread to every screen safely; this switch turns it on app-wide.
final bentoEverywhereProvider =
    AsyncNotifierProvider<BentoEverywhereNotifier, bool>(
      BentoEverywhereNotifier.new,
    );

class BentoEverywhereNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.bento_everywhere';

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

/// Resolve whether a screen should render its bento variant: the global
/// "Bento everywhere" switch OR the screen's own per-screen toggle. Pass the
/// per-screen provider's current value. Centralises the OR so every screen
/// reads it the same way.
///
/// ```dart
/// final bento = bentoEnabled(
///   ref,
///   perScreen: ref.watch(programHubBentoProvider).value,
/// );
/// ```
bool bentoEnabled(WidgetRef ref, {required bool? perScreen}) {
  final global = ref.watch(bentoEverywhereProvider).value ?? false;
  return global || (perScreen ?? false);
}
