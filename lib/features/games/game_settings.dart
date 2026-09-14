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

/// **How long a round is** — the knob a substitute actually reaches for.
///
/// "We have ten minutes" is the most common constraint in the building, and
/// before this exactly two of forty-one games had any knob at all, so the
/// answer was always "run it and stop whenever", which is how a round ends
/// without an ending. Eleven games want this same setting with a different
/// noun (words · letters · prompts · riddles · statements · starters), so it
/// is one spelling with the noun passed in rather than eleven near-copies
/// that drift in range and wording.
///
/// The id is fixed so every game reads it the same way — see [roundsFrom].
IntSetting roundLength({
  required String label,
  int initial = 8,
  int min = 3,
  int max = 20,
}) => IntSetting(
  id: roundLengthId,
  label: label,
  min: min,
  max: max,
  initial: initial,
);

/// The key [roundLength] writes under.
const String roundLengthId = 'rounds';

/// Read the chosen round length, falling back to [fallback] when the game was
/// seeded without settings — a cast from an older phone, a test fixture, or
/// any path that calls `initialState` rather than `initialStateFor`.
int roundsFrom(Map<String, Object?> values, {required int fallback}) {
  final v = values[roundLengthId];
  return v is int && v > 0 ? v : fallback;
}

/// **How long the sand lasts**, in seconds — the shared "how long" knob, for
/// the same reason [roundLength] is the shared "how many".
///
/// A timed game's duration is the single thing a teacher most wants to change
/// and the thing most likely to be a `static const` somebody typed once: an
/// afterschool room of six-year-olds and a room of eleven-year-olds do not
/// want the same ninety seconds.
IntSetting seconds({
  required String label,
  int initial = 90,
  int min = 30,
  int max = 300,
  int step = 15,
}) => IntSetting(
  id: secondsId,
  label: label,
  min: min,
  max: max,
  initial: initial,
  step: step,
  hint: 'Seconds',
);

/// The key [seconds] writes under.
const String secondsId = 'seconds';

/// Read the chosen duration, falling back to [fallback] when the game was
/// seeded without settings — the same contract as [roundsFrom].
int secondsFrom(Map<String, Object?> values, {required int fallback}) {
  final v = values[secondsId];
  return v is int && v > 0 ? v : fallback;
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
