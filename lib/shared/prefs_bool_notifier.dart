import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS a direct dep; the analyzer sometimes warns spuriously
// across the pub workspace boundary.
import 'package:shared_preferences/shared_preferences.dart';

/// A SharedPreferences-backed boolean setting — the per-device toggle
/// pattern repeated across the settings notifiers (live entities, the
/// grid-reveal emoji mix, the bento switches…). Subclasses supply the
/// pref key and default; expose via `AsyncNotifierProvider<X, bool>`.
abstract class PrefsBoolNotifier extends AsyncNotifier<bool> {
  SharedPreferences? _prefs;

  /// The SharedPreferences key the value persists under.
  String get prefsKey;

  /// What the toggle reads as before the user ever sets it.
  bool get defaultValue;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<bool> build() async {
    final prefs = await _instance;
    return prefs.getBool(prefsKey) ?? defaultValue;
  }

  Future<void> set({required bool value}) async {
    final prefs = await _instance;
    await prefs.setBool(prefsKey, value);
    state = AsyncData(value);
  }
}
