import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Last-N tools the user has opened from the catalog. Turns the
/// static reference into a living tool — the FIFTH time a teacher
/// comes back to "The 2x10" they shouldn't have to scroll or search
/// for it.
///
/// Persisted via SharedPreferences (account-agnostic device-local
/// preference, same shape as omnibox recents). No cloud sync — what
/// you've used recently is private to your device.
///
/// Capacity: 5 entries. The Red Team flagged that crisis tools
/// should be reachable in under 5 seconds; a 5-slot "Recent"
/// shelf at the top of the catalog gets the common case to 1 tap.
final toolkitRecentsProvider =
    AsyncNotifierProvider<ToolkitRecentsNotifier, List<String>>(
  ToolkitRecentsNotifier.new,
);

class ToolkitRecentsNotifier extends AsyncNotifier<List<String>> {
  /// Storage key.
  static const _kKey = 'toolkit.recent_slugs';

  /// Cap — keeping the shelf small forces it to surface what's
  /// genuinely high-frequency, not a long unsorted list.
  static const _kMax = 5;

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? const [];
    return List.unmodifiable(raw.take(_kMax).toList());
  }

  /// Bump the given slug to position 0 of the recents list,
  /// de-duplicating prior entries and truncating to [_kMax]. Called
  /// from the per-tool screen the moment it lands (so search-tap and
  /// catalog-tap both register).
  Future<void> touch(String slug) async {
    final current = state.value ?? const <String>[];
    final next = [
      slug,
      for (final s in current)
        if (s != slug) s,
    ].take(_kMax).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, next);
    state = AsyncData(List.unmodifiable(next));
  }

  /// Clear the shelf — exposed for a future "Clear recents" affordance
  /// or a privacy-erase flow.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    state = const AsyncData(<String>[]);
  }
}
