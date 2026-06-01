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

/// A round of [count] questions, cycling the mechanics so the sequence is
/// varied (choose → type → sequence → true/false → …). Deterministic for a
/// seeded [rng]; the screen passes a fresh Random, tests a fixed one.
List<MathQuestion> generateMathRound(Random rng, {int count = 8}) {
  const order = [
    MathMechanic.choose,
    MathMechanic.sequence,
    MathMechanic.trueFalse,
  ];
  return [for (var i = 0; i < count; i++) _gen(order[i % order.length], rng)];
}

MathQuestion _gen(MathMechanic m, Random rng) => switch (m) {
  MathMechanic.choose => _choose(rng),
  MathMechanic.sequence => _sequence(rng),
  MathMechanic.trueFalse => _trueFalse(rng),
};

int _r(Random rng, int min, int max) => min + rng.nextInt(max - min + 1);

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

MathQuestion _choose(Random rng) {
  final a = _r(rng, 1, 12);
  final b = _r(rng, 1, 12);
  final ans = a + b;
  return MathQuestion(
    mechanic: MathMechanic.choose,
    prompt: '$a + $b',
    answer: ans,
    choices: _withDistractors(rng, ans),
  );
}

MathQuestion _sequence(Random rng) {
  final start = _r(rng, 1, 6);
  final step = _r(rng, 1, 5);
  final terms = [for (var k = 0; k < 4; k++) start + step * k];
  final ans = start + step * 4;
  return MathQuestion(
    mechanic: MathMechanic.sequence,
    prompt: '${terms.join(', ')}, ?',
    answer: ans,
    choices: _withDistractors(rng, ans),
  );
}

MathQuestion _trueFalse(Random rng) {
  final a = _r(rng, 1, 12);
  final b = _r(rng, 1, 12);
  final real = a + b;
  final showReal = rng.nextBool();
  final off = [-2, -1, 1, 2][rng.nextInt(4)];
  final shown = showReal ? real : real + off;
  return MathQuestion(
    mechanic: MathMechanic.trueFalse,
    prompt: '$a + $b = $shown',
    statementTrue: shown == real,
  );
}
