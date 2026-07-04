// The Math game generator (docs/ACTIVITY_ROADMAP.md Wave 2). Pure + local
// — no AI. Three host-present mechanics (choose / sequence / true-false);
// no typed input. Deterministic for a seeded Random.

import 'dart:math';

import 'package:differentworld/features/activity_runtime/math_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateMathRound', () {
    test('produces `count` questions cycling the three mechanics', () {
      final qs = generateMathRound(Random(7)); // default count 8
      expect(qs, hasLength(8));
      expect(qs[0].mechanic, MathMechanic.choose);
      expect(qs[1].mechanic, MathMechanic.sequence);
      expect(qs[2].mechanic, MathMechanic.trueFalse);
      expect(qs[3].mechanic, MathMechanic.choose);
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
      final seq = qs[1];
      expect(seq.mechanic, MathMechanic.sequence);
      expect(seq.choices, contains(seq.answer));
    });

    test(
      'isCorrect still resolves the answer (drives the Reveal highlight)',
      () {
        final qs = generateMathRound(Random(9), count: 4);
        final choose = qs[0];
        expect(choose.isCorrect(choose.answer), isTrue);
        expect(choose.isCorrect(choose.answer + 1), isFalse);

        final tf = qs[2];
        expect(tf.mechanic, MathMechanic.trueFalse);
        expect(tf.isCorrect(tf.statementTrue!), isTrue);
        expect(tf.isCorrect(!tf.statementTrue!), isFalse);
      },
    );
  });

  group('operations + range (the Settings contract)', () {
    test('count + a tight range are honored', () {
      final qs = generateMathRound(Random(1), count: 12, min: 2, max: 5);
      expect(qs, hasLength(12));
    });

    test('subtraction never goes negative', () {
      final qs = generateMathRound(
        Random(2),
        count: 9,
        operations: {MathOp.subtract},
      );
      for (final q in qs.where((q) => q.mechanic == MathMechanic.choose)) {
        expect(q.answer, greaterThanOrEqualTo(0), reason: q.prompt);
        expect(q.prompt, contains('−'));
      }
    });

    test('division shows ÷ and the answer stays a whole option', () {
      final qs = generateMathRound(
        Random(4),
        count: 6,
        min: 2,
        max: 9,
        operations: {MathOp.divide},
      );
      final choose = qs.where((q) => q.mechanic == MathMechanic.choose);
      expect(choose.any((q) => q.prompt.contains('÷')), isTrue);
      for (final q in choose) {
        expect(q.answer, greaterThanOrEqualTo(0));
        expect(q.choices, contains(q.answer));
      }
    });

    test('multiplication shows the × sign', () {
      final qs = generateMathRound(
        Random(6),
        count: 3,
        operations: {MathOp.multiply},
      );
      expect(qs.any((q) => q.prompt.contains('×')), isTrue);
    });

    test('empty operations falls back to addition (never empty)', () {
      final qs = generateMathRound(Random(8), count: 3, operations: const {});
      expect(qs, hasLength(3));
    });
  });
}
