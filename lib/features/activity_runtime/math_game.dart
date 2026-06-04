import 'dart:math';

/// The Math GAME (distinct from the "Many Paths" inverse exercise): a
/// sequence of quick questions, one at a time — pick-an-option, true/false,
/// what-comes-next sequences. Host-paced: the room answers ALOUD, the
/// teacher Reveals (no typing, no grading). All generated LOCALLY
/// (arithmetic is free + infinite — no AI, no bank, per CONTENT_BANK.md §1).

enum MathMechanic {
  /// Pick the answer from options.
  choose,

  /// Is the statement true? (True / False.)
  trueFalse,

  /// What comes next in the sequence?
  sequence,
}

class MathQuestion {
  const MathQuestion({
    required this.mechanic,
    required this.prompt,
    this.answer = 0,
    this.choices = const <int>[],
    this.statementTrue,
  });

  final MathMechanic mechanic;

  /// The displayed problem: "7 + 5", "2, 4, 6, ?", "8 + 1 = 10".
  final String prompt;

  /// The correct number (choose / type / sequence).
  final int answer;

  /// Options for choose / sequence (includes [answer]).
  final List<int> choices;

  /// For [MathMechanic.trueFalse]: whether the shown statement is true.
  final bool? statementTrue;

  /// `given` is an int for choose/type/sequence, a bool for trueFalse.
  bool isCorrect(Object given) {
    if (mechanic == MathMechanic.trueFalse) return given == statementTrue;
    return given == answer;
  }
}

/// Operations a round can draw from. Subtraction never goes negative;
/// division is always clean (whole-number answers) — kid-appropriate.
enum MathOp { add, subtract, multiply, divide }

/// A round of [count] questions over operands in [min]..[max], drawing from
/// [operations] (defaults to addition). Mechanics cycle (choose → sequence →
/// true/false). Deterministic for a seeded [rng]; the screen passes a fresh
/// Random, tests a fixed one.
List<MathQuestion> generateMathRound(
  Random rng, {
  int count = 8,
  int min = 1,
  int max = 12,
  Set<MathOp> operations = const {MathOp.add},
}) {
  final lo = min < 0 ? 0 : min;
  final hi = max <= lo ? lo + 1 : max;
  final ops = (operations.isEmpty ? const {MathOp.add} : operations).toList();
  const mechanics = [
    MathMechanic.choose,
    MathMechanic.sequence,
    MathMechanic.trueFalse,
  ];
  return [
    for (var i = 0; i < count; i++)
      _gen(mechanics[i % mechanics.length], rng, lo, hi, ops[i % ops.length]),
  ];
}

MathQuestion _gen(MathMechanic m, Random rng, int lo, int hi, MathOp op) =>
    switch (m) {
      MathMechanic.choose => _choose(rng, lo, hi, op),
      MathMechanic.sequence => _sequence(rng, lo, hi),
      MathMechanic.trueFalse => _trueFalse(rng, lo, hi, op),
    };

int _r(Random rng, int min, int max) => min + rng.nextInt(max - min + 1);

/// A problem for [op] over operands in [lo]..[hi] → (prompt, answer).
/// Subtraction orders the operands so the result is ≥ 0; division builds from
/// the answer so it divides cleanly.
(String, int) _problem(Random rng, int lo, int hi, MathOp op) {
  switch (op) {
    case MathOp.add:
      final a = _r(rng, lo, hi);
      final b = _r(rng, lo, hi);
      return ('$a + $b', a + b);
    case MathOp.subtract:
      final x = _r(rng, lo, hi);
      final y = _r(rng, lo, hi);
      final a = x >= y ? x : y;
      final b = x >= y ? y : x;
      return ('$a − $b', a - b);
    case MathOp.multiply:
      final a = _r(rng, lo, hi);
      final b = _r(rng, lo, hi);
      return ('$a × $b', a * b);
    case MathOp.divide:
      final b = _r(rng, lo < 1 ? 1 : lo, hi); // divisor ≥ 1
      final ans = _r(rng, lo, hi);
      return ('${ans * b} ÷ $b', ans);
  }
}

/// [answer] + 3 distinct non-negative distractors, shuffled.
List<int> _withDistractors(Random rng, int answer) {
  final set = <int>{answer};
  var guard = 0;
  while (set.length < 4 && guard < 50) {
    guard++;
    final cand = answer + (rng.nextInt(7) - 3); // -3..+3
    if (cand >= 0) set.add(cand);
  }
  var n = answer + 1;
  while (set.length < 4) {
    set.add(n);
    n++;
  }
  return set.toList()..shuffle(rng);
}

MathQuestion _choose(Random rng, int lo, int hi, MathOp op) {
  final (prompt, ans) = _problem(rng, lo, hi, op);
  return MathQuestion(
    mechanic: MathMechanic.choose,
    prompt: prompt,
    answer: ans,
    choices: _withDistractors(rng, ans),
  );
}

MathQuestion _sequence(Random rng, int lo, int hi) {
  final start = _r(rng, lo, hi);
  final step = _r(rng, 1, ((hi - lo) ~/ 2).clamp(1, 5));
  final terms = [for (var k = 0; k < 4; k++) start + step * k];
  final ans = start + step * 4;
  return MathQuestion(
    mechanic: MathMechanic.sequence,
    prompt: '${terms.join(', ')}, ?',
    answer: ans,
    choices: _withDistractors(rng, ans),
  );
}

MathQuestion _trueFalse(Random rng, int lo, int hi, MathOp op) {
  final (base, real) = _problem(rng, lo, hi, op);
  final showReal = rng.nextBool();
  final off = [-2, -1, 1, 2][rng.nextInt(4)];
  final shown = showReal ? real : real + off;
  return MathQuestion(
    mechanic: MathMechanic.trueFalse,
    prompt: '$base = $shown',
    statementTrue: shown == real,
  );
}
