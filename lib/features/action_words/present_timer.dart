import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS a direct dep in pubspec.yaml; the analyzer
// sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// "m:ss" for a countdown — 300 → "5:00", 90 → "1:30". Pure so the present
/// surface + its timer sheet share one formatter.
String mmss(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final rem = (s % 60).toString().padLeft(2, '0');
  return '$m:$rem';
}

/// The teacher's **remembered custom timer durations** (seconds), most-recent
/// first, capped to a handful. The present-surface timer (`BeatPresenter`)
/// suggests a per-beat default but lets the teacher dial any length; whatever
/// they dial lands here and comes back as a one-tap chip next time — so
/// "customizable" sticks across beats and sessions. Persisted in
/// SharedPreferences (device-local UI preference; not synced PII).
final presentTimerProvider =
    AsyncNotifierProvider<PresentTimerNotifier, List<int>>(
      PresentTimerNotifier.new,
    );

class PresentTimerNotifier extends AsyncNotifier<List<int>> {
  static const _kKey = 'present.timer.custom_seconds';
  static const _max = 4;

  @override
  Future<List<int>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? const <String>[];
    final out = <int>[];
    for (final s in raw) {
      final v = int.tryParse(s);
      if (v != null && v > 0) out.add(v);
    }
    return out;
  }

  /// Record a custom duration: dedupe, move-to-front, cap, persist.
  Future<void> remember(int seconds) async {
    if (seconds <= 0) return;
    final current = state.value ?? const <int>[];
    final next = <int>[
      seconds,
      for (final s in current)
        if (s != seconds) s,
    ].take(_max).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, [for (final s in next) '$s']);
    state = AsyncData(next);
  }
}
