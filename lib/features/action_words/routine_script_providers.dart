import 'dart:convert';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/action_words/block_run.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-space overrides of the everyday-routine run-scripts (arrival / meal /
/// rest / pickup / transition / welcome / free-play). Reads are offline-first
/// (currentSpaceProvider is a Drift stream); writes are optimistic through
/// [RoutineScriptActions] — the same caps-JSON read-modify-write as the day
/// templates. A routine absent from the map uses its baked-in
/// [defaultRoutineScript], so the stored map only ever holds what a program
/// actually customized.

/// Decode the `routine_scripts` cap into a map of overrides. Null/garbage safe.
Map<RoutineKind, BlockRunScript> decodeRoutineScripts(String? raw) {
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const {};
    final out = <RoutineKind, BlockRunScript>{};
    decoded.forEach((key, value) {
      final r = RoutineKind.fromName(key is String ? key : null);
      if (r == null || value is! Map) return;
      final steps = [
        for (final s in (value['steps'] as List? ?? const []))
          if (s is String) s,
      ];
      final tools = [
        for (final s in (value['tools'] as List? ?? const []))
          if (s is String) s,
      ];
      out[r] = (steps: steps, tools: tools);
    });
    return out;
  } on FormatException {
    return const {};
  }
}

/// Encode the override map back to the cap JSON string.
String encodeRoutineScripts(Map<RoutineKind, BlockRunScript> scripts) =>
    jsonEncode({
      for (final e in scripts.entries)
        e.key.name: {'steps': e.value.steps, 'tools': e.value.tools},
    });

/// The program's routine-script overrides, live off the Space's caps. Gated on
/// the cap STRING (not the whole Space) so it only re-decodes when the
/// `routine_scripts` value itself changes.
final customRoutineScriptsProvider = Provider<Map<RoutineKind, BlockRunScript>>((
  ref,
) {
  final raw = ref.watch(
    currentSpaceProvider.select(
      (s) => s.value?.caps.getString(SpaceCaps.routineScripts),
    ),
  );
  return decodeRoutineScripts(raw);
});

/// One routine's override, or null when the program hasn't customized it (the
/// caller falls back to [defaultRoutineScript]).
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final customRoutineScriptProvider = Provider.family<BlockRunScript?, RoutineKind>(
  (ref, r) => ref.watch(customRoutineScriptsProvider)[r],
);

/// The EFFECTIVE script for a routine — the override if set, else the baked-in
/// default. What the editor seeds its fields from and what the run uses.
// ignore: specify_nonobvious_property_types
final effectiveRoutineScriptProvider =
    Provider.family<BlockRunScript, RoutineKind>(
      (ref, r) =>
          ref.watch(customRoutineScriptProvider(r)) ?? defaultRoutineScript(r),
    );

/// Mutations on the routine-script overrides. Each write is a read-modify-write
/// of ONE caps JSON string, so — exactly like `DayTemplateActions` — every
/// mutation is serialized through a `_pending` queue, or two racing edits would
/// both read the same pre-write state and the second `_save` would clobber the
/// first (CLAUDE.md "A list stored in caps JSON needs a serialized
/// read-modify-write"). Optimistic + offline-first like every other write.
class RoutineScriptActions {
  RoutineScriptActions(this._ref);
  final Ref _ref;

  Future<Map<RoutineKind, BlockRunScript>> _load(String spaceId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final s = await db.spacesDao.findById(spaceId);
    return decodeRoutineScripts(s?.caps.getString(SpaceCaps.routineScripts));
  }

  Future<void> _save(String spaceId, Map<RoutineKind, BlockRunScript> map) {
    return _ref
        .read(spaceCapActionsProvider)
        .setStringCap(
          spaceId,
          SpaceCaps.routineScripts,
          encodeRoutineScripts(map),
        );
  }

  Future<void> _pending = Future<void>.value();

  Future<void> _mutate(
    String spaceId,
    Map<RoutineKind, BlockRunScript> Function(Map<RoutineKind, BlockRunScript>)
    update,
  ) {
    final op = _pending.then((_) async {
      final map = await _load(spaceId);
      await _save(spaceId, update(Map<RoutineKind, BlockRunScript>.of(map)));
    });
    // The queue's tail must never be a rejected future, or one failed write
    // would block every later mutation. Callers still see this op's own error.
    _pending = op.catchError((Object _) {});
    return op;
  }

  /// Set (or replace) one routine's override. Blank steps/tools are trimmed
  /// out; an override with no steps is meaningless, so that clears it instead
  /// (it reverts to the default).
  Future<void> setScript({
    required String spaceId,
    required RoutineKind routine,
    required BlockRunScript script,
  }) {
    final steps = [
      for (final s in script.steps)
        if (s.trim().isNotEmpty) s.trim(),
    ];
    final tools = [
      for (final t in script.tools)
        if (t.trim().isNotEmpty) t.trim(),
    ];
    return _mutate(spaceId, (m) {
      if (steps.isEmpty) {
        m.remove(routine);
      } else {
        m[routine] = (steps: steps, tools: tools);
      }
      return m;
    });
  }

  /// Drop a routine's override — it reverts to [defaultRoutineScript].
  Future<void> resetScript({
    required String spaceId,
    required RoutineKind routine,
  }) => _mutate(spaceId, (m) => m..remove(routine));
}

final routineScriptActionsProvider = Provider<RoutineScriptActions>(
  RoutineScriptActions.new,
);
