import 'dart:convert';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Program policy** for the present-surface timer: the "house" preset
/// durations (whole minutes) the director sets in program settings.
///
/// This is one of three deliberately-separated timer concerns:
///   - the per-beat *suggestion* lives on the beat (`DayBeat.suggestedSeconds`);
///   - this program *policy* lives on the Space caps (synced, director-authored);
///   - the per-device *remembered customs* live in SharedPreferences
///     (`present_timer.dart`).
/// The present-surface timer sheet composes all three; none of them know
/// about the others.

/// The fallback presets when a program hasn't set its own (and the floor a
/// blank/corrupt cap decodes to).
const List<int> kDefaultTimerPresetMinutes = [1, 2, 5, 10];

/// Whole-minute bounds for a preset — a classroom timer below 1 or above 60
/// minutes isn't a "quick" preset.
const int kMinPresetMinutes = 1;
const int kMaxPresetMinutes = 60;

/// Sanitize a preset list: keep whole minutes in range, dedupe, sort. Empty
/// in → empty out (the caller decides whether to fall back to the default).
List<int> sanitizeTimerPresets(Iterable<int> minutes) {
  final out = <int>[];
  for (final m in minutes) {
    if (m >= kMinPresetMinutes && m <= kMaxPresetMinutes && !out.contains(m)) {
      out.add(m);
    }
  }
  out.sort();
  return out;
}

/// Decode the caps JSON (a list of minutes) → a clean preset list. Anything
/// invalid, empty, or out of range falls back to [kDefaultTimerPresetMinutes].
List<int> decodeTimerPresets(String? raw) {
  if (raw == null || raw.isEmpty) return kDefaultTimerPresetMinutes;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return kDefaultTimerPresetMinutes;
    final clean = sanitizeTimerPresets([
      for (final v in decoded)
        if (v is num) v.toInt(),
    ]);
    return clean.isEmpty ? kDefaultTimerPresetMinutes : clean;
  } on FormatException {
    return kDefaultTimerPresetMinutes;
  }
}

String encodeTimerPresets(List<int> minutes) =>
    jsonEncode(sanitizeTimerPresets(minutes));

/// The program's live house presets (minutes). Offline-first — reads off the
/// Space caps Drift stream, re-decoding only when the `timer_presets` string
/// itself changes (not on every unrelated cap write).
final houseTimerPresetsProvider = Provider<List<int>>((ref) {
  final raw = ref.watch(
    currentSpaceProvider.select(
      (s) => s.value?.caps.getString(SpaceCaps.timerPresets),
    ),
  );
  return decodeTimerPresets(raw);
});

/// Director-only write of the house presets — replaces the whole list at once
/// (the editor holds the full list, so there's no *per-element* read-modify-
/// write like the day-template library has).
///
/// BUT `setStringCap` itself is a read-modify-write of the shared `capabilities`
/// JSONB blob (load all caps → merge this one key → write back). Two rapid
/// edits — deleting two chips fast — would each load the same pre-write blob
/// and the later write would silently clobber the earlier. That's the
/// documented "list stored in a caps cell" trap. The actions provider is a
/// stable singleton, so chaining every write through `_pending` serializes
/// them: each `setStringCap` reads the result of the one before it.
class HouseTimerActions {
  HouseTimerActions(this._ref);
  final Ref _ref;

  Future<void> _pending = Future<void>.value();

  Future<void> setPresetMinutes(String spaceId, List<int> minutes) {
    final op = _pending.then(
      (_) => _ref
          .read(spaceCapActionsProvider)
          .setStringCap(
            spaceId,
            SpaceCaps.timerPresets,
            encodeTimerPresets(minutes),
          ),
    );
    // The queue's tail must never reject, or one failed write would block every
    // later one; the caller still sees this op's own error via the returned op.
    _pending = op.catchError((Object _) {});
    return op;
  }
}

final houseTimerActionsProvider = Provider<HouseTimerActions>(
  HouseTimerActions.new,
);
