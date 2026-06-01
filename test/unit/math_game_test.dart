// The Math game generator (docs/ACTIVITY_RUNTIME.md). Pure + local — no
// AI. Deterministic for a seeded Random.

import 'dart:math';

import 'package:differentworld/features/activity_runtime/math_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateMathRound', () {
    test('produces `count` questions cycling the mechanics', () {
      final qs = generateMathRound(Random(7)); // default count 8
      expect(qs, hasLength(8));
      expect(qs[0].mechanic, MathMechanic.choose);
      expect(qs[1].mechanic, MathMechanic.type);
      expect(qs[2].mechanic, MathMechanic.sequence);
      expect(qs[3].mechanic, MathMechanic.trueFalse);
      expect(qs[4].mechanic, MathMechanic.choose);
    });

    test('choose: the answer is among 4 distinct choices', () {
      final qs = generateMathRound(Random(3), count: 4);
      final choose = qs[0];
      expect(choose.choices, hasLength(4));
      expect(choose.choices.toSet(), hasLength(4), reason: 'distinct');
      expect(choose.choices, contains(choose.answer));
    });

    test('sequence: the next term is among the choices', () {
      final qs = generateMathRound(Random(5), count: 3);
      final seq = qs[2];
      expect(seq.choices, contains(seq.answer));
    });

    test(
      'isCorrect: numeric for choose/type/sequence, bool for true/false',
      () {
        final qs = generateMathRound(Random(9), count: 4);
        final choose = qs[0];
        expect(choose.isCorrect(choose.answer), isTrue);
        expect(choose.isCorrect(choose.answer + 1), isFalse);

        final tf = qs[3];
        expect(tf.isCorrect(tf.statementTrue!), isTrue);
        expect(tf.isCorrect(!tf.statementTrue!), isFalse);
      },
    );
  });
}
