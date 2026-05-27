import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

/// Recently selected entry ids (by `OmniboxEntry.id`). Most-recent
/// first, capped at 10. Persisted via SharedPreferences so it
/// survives app restarts.
final recentOmniboxIdsProvider =
    AsyncNotifierProvider<RecentOmniboxIds, List<String>>(
  RecentOmniboxIds.new,
);

class RecentOmniboxIds extends AsyncNotifier<List<String>> {
  static const _kKey = 'omnibox.recent.ids';
  static const _maxItems = 10;

  /// Wave 141: which omnibox ids count as "specific person/kid"
  /// surfaces — these never belong in the recents list. Tapping a
  /// kid's profile once shouldn't make the kid feel like a permanent
  /// shortcut: it leaks "child choice" affordance into surfaces that
  /// should be person-agnostic (the survey landing, for one).
  ///
  /// Subject verbs (`subject:<id>:observation.new`,
  /// `subject:<id>:messages`, etc.) ARE allowed — those are specific
  /// actions a director might repeat. The bare `subject:<id>` is the
  /// only one filtered.
  static bool _isExcluded(String id) {
    if (!id.startsWith('subject:')) return false;
    // `subject:<uuid>` alone (no trailing `:verb`) → exclude.
    return ':'.allMatches(id).length == 1;
  }

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? const <String>[];
    // Wave 141: prune any excluded ids that were persisted before
    // this filter shipped. One-shot cleanup; rewrite back if we
    // dropped anything.
    final clean = raw.where((id) => !_isExcluded(id)).toList(growable: false);
    if (clean.length != raw.length) {
      await prefs.setStringList(_kKey, clean);
    }
    return clean;
  }

  /// Bump an id to the head of the recent list. Idempotent — if it's
  /// already there it just moves to the front. Excluded ids (bare
  /// kid profiles) silently skip the write.
  Future<void> bump(String id) async {
    if (_isExcluded(id)) return;
    final current = state.value ?? const <String>[];
    final next = [id, ...current.where((x) => x != id)];
    final trimmed =
        next.length > _maxItems ? next.sublist(0, _maxItems) : next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, trimmed);
    state = AsyncData(trimmed);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    state = const AsyncData(<String>[]);
  }
}

/// User-pinned entry ids — the omnibox's "favorites." Insertion order
/// is preserved (first-pinned shows first).
final pinnedOmniboxIdsProvider =
    AsyncNotifierProvider<PinnedOmniboxIds, List<String>>(
  PinnedOmniboxIds.new,
);

class PinnedOmniboxIds extends AsyncNotifier<List<String>> {
  static const _kKey = 'omnibox.pinned.ids';

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kKey) ?? const <String>[];
  }

  Future<void> toggle(String id) async {
    final current = state.value ?? const <String>[];
    final next = current.contains(id)
        ? current.where((x) => x != id).toList()
        : [...current, id];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, next);
    state = AsyncData(next);
  }

  bool isPinned(String id) =>
      (state.value ?? const <String>[]).contains(id);
}

/// Context tag for "for you now" boosting. Time-of-day driven for
/// v1; later we'll fold in "you have unread messages", "there's a
/// flagged kid", etc.
String currentContextTag(DateTime now) {
  final h = now.hour;
  if (h < 11) return 'morning';
  if (h < 14) return 'midday';
  if (h < 18) return 'afternoon';
  return 'evening';
}

/// Convenience — fires bump in a "fire-and-forget" way from sync
/// callbacks. Errors are swallowed; recents are a nicety, not a
/// correctness path.
void bumpRecent(WidgetRef ref, String id) {
  unawaited(() async {
    try {
      await ref.read(recentOmniboxIdsProvider.notifier).bump(id);
    } on Object catch (_) {
      // Swallow — recents are best-effort.
    }
  }());
}
