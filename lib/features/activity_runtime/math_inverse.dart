import 'package:differentworld/features/activity_runtime/activity_script.dart';
import 'package:differentworld/features/activity_runtime/expression_eval.dart';

/// The Math inverse archetype (docs/ACTIVITY_RUNTIME.md §6) — "how many
/// paths to N?". Math flips from *find the answer* to *find the ways*, and
/// the learner generates. Fully local, deterministic, offline: no AI, no
/// network, no privacy surface.

/// The verdict on a learner's coined expression. A record, so a UI can
/// pattern-match it directly.
typedef MathVerdict = ({
  bool valid, // parses + evaluates
  bool equals, // == target
  bool novel, // not already in the room's set
  double? value, // what it evaluated to (null when invalid)
});

/// Canonical form for dedupe / novelty: glyphs normalized, spaces dropped.
String canonicalizeExpression(String expr) => expr
    .replaceAll(' ', '')
    .replaceAll('×', '*')
    .replaceAll('÷', '/')
    .replaceAll('−', '-')
    .replaceAll('–', '-');

/// Judge a learner's expression against [target] and the room's existing
/// answers. Validation is a hardcoded capability (computation), not a
/// data-rule — the rule engine would only *trigger* it.
MathVerdict validateMathExpression(
  String input,
  int target, {
  Set<String> roomAnswers = const {},
}) {
  double value;
  try {
    value = evaluateExpression(input);
  } on FormatException {
    return (valid: false, equals: false, novel: false, value: null);
  }
  if (!value.isFinite) {
    return (valid: false, equals: false, novel: false, value: value);
  }
  final equals = (value - target).abs() < 1e-9;
  final canon = canonicalizeExpression(input);
  final novel = !roomAnswers.map(canonicalizeExpression).contains(canon);
  return (valid: true, equals: equals, novel: novel, value: value);
}

/// Generate up to [count] DISTINCT expressions that evaluate to [target],
/// interleaved across operations so the first few show real variety (the
/// pedagogical point — different roads, same place). Deterministic; the UI
/// can shuffle with a seed for freshness (a follow-up).
List<String> generateInverseExpressions(int target, {int count = 6}) {
  const reach = 12; // how far to range for subtraction / division seeds
  final muls = <String>[
    for (var a = 2; a * a <= target; a++)
      if (target % a == 0) '$a × ${target ~/ a}',
  ];
  final adds = <String>[
    for (var b = 1; b < target; b++) '${target - b} + $b',
  ];
  final subs = <String>[
    for (var b = 1; b <= reach; b++) '${target + b} − $b',
  ];
  final divs = <String>[
    for (var k = 2; k <= reach; k++) '${target * k} ÷ $k',
  ];

  // Round-robin so variety leads, not 11 additions in a row.
  final lists = [muls, adds, subs, divs];
  final out = <String>[];
  final seen = <String>{};
  var added = true;
  for (var i = 0; added && out.length < count; i++) {
    added = false;
    for (final list in lists) {
      if (i >= list.length) continue;
      added = true;
      final e = list[i];
      if (seen.add(canonicalizeExpression(e)) && out.length < count) {
        out.add(e);
      }
    }
  }
  return out;
}

/// Build the conducted Math activity for [target]: present → create →
/// reveal → ponder. The make-and-keep loop (§4) with no generator UI yet —
/// the create phase uses [validateMathExpression]; the reveal can seed
/// with [generateInverseExpressions].
ScriptedActivity mathInverseActivity(int target) => ScriptedActivity(
  id: 'math-inverse-$target',
  title: 'How many paths to $target?',
  phases: [
    Phase(
      id: 'present',
      mode: ActivityMode.present,
      prompt: 'The answer is $target.',
    ),
    Phase(
      id: 'create',
      mode: ActivityMode.create,
      prompt: 'Invent a question that makes $target — one nobody else will.',
      pacing: PacingKind.perLearner,
    ),
    Phase(
      id: 'reveal',
      mode: ActivityMode.present,
      prompt: 'So many paths — and every one lands on $target.',
    ),
    const Phase(
      id: 'ponder',
      mode: ActivityMode.ponder,
      prompt: 'Different roads, same place.',
      pacing: PacingKind.timer,
      duration: Duration(seconds: 20),
    ),
  ],
);
