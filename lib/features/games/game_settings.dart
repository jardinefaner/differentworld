import 'package:flutter/foundation.dart';

/// A tunable param for a game (docs/FEATURE_CHECKLISTS.md — the Settings
/// contract). A `GameDefinition` returns a list of these from `settings`; the
/// runner renders them in a pre-game sheet and collects the chosen values into
/// a `Map<String, Object?>` keyed by [id], which it passes to
/// `GameDefinition.initialStateFor`. Sealed so the sheet's switch is
/// exhaustive — adding a setting kind is a deliberate, one-place change.
@immutable
sealed class GameSetting {
  const GameSetting({required this.id, required this.label, this.hint});

  final String id;
  final String label;
  final String? hint;

  Object? get defaultValue;
}

/// An integer the teacher steps up/down — smallest / biggest number, how many
/// questions. Clamped to [min]..[max].
class IntSetting extends GameSetting {
  const IntSetting({
    required super.id,
    required super.label,
    required this.min,
    required this.max,
    required this.initial,
    this.step = 1,
    super.hint,
  });

  final int min;
  final int max;
  final int initial;
  final int step;

  @override
  Object? get defaultValue => initial;
}

/// A multi-pick where at least one option stays selected — operations
/// (+ − × ÷), topics, mechanics. Options are `(value, label)` pairs.
class MultiSetting extends GameSetting {
  const MultiSetting({
    required super.id,
    required super.label,
    required this.options,
    required this.initial,
    super.hint,
  });

  final List<({String value, String label})> options;
  final Set<String> initial;

  @override
  Object? get defaultValue => initial;
}

/// The default value map for a settings list (each setting's default), keyed
/// by id — what the runner starts from before the teacher tunes anything.
Map<String, Object?> defaultSettingValues(List<GameSetting> settings) => {
  for (final s in settings) s.id: s.defaultValue,
};

/// Typed reads for a values map (the runner passes `Map<String, Object?>`).
extension GameSettingValues on Map<String, Object?> {
  int intSetting(String id, int fallback) => (this[id] as int?) ?? fallback;

  Set<String> multiSetting(String id, Set<String> fallback) {
    final v = this[id];
    return v is Set<String> ? v : fallback;
  }
}
