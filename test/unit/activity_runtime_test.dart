// The Math inverse archetype + phase-runner proof (docs/ACTIVITY_RUNTIME.md
// §8). Pure, offline, deterministic — the conducted loop's logic with zero
// AI and zero network.

import 'package:differentworld/features/activity_runtime/activity_script.dart';
import 'package:differentworld/features/activity_runtime/expression_eval.dart';
import 'package:differentworld/features/activity_runtime/math_inverse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('expression evaluator', () {
    test('evaluates the four ops + parens + glyphs + unary minus', () {
      expect(evaluateExpression('3 × 4'), 12);
      expect(evaluateExpression('24 ÷ 2'), 12);
      expect(evaluateExpression('6 + 6'), 12);
      expect(evaluateExpression('15 − 3'), 12); // typographic minus
      expect(evaluateExpression('2 × (3 + 3)'), 12);
      expect(evaluateExpression('-4 + 16'), 12);
      expect(evaluateExpression('37 / 3'), closeTo(12.333, 0.001));
    });

    test('throws on malformed input and division by zero', () {
      expect(() => evaluateExpression('3 +'), throwsFormatException);
      expect(() => evaluateExpression('(3'), throwsFormatException);
      expect(() => evaluateExpression('3 4'), throwsFormatException);
      expect(() => evaluateExpression(''), throwsFormatException);
      expect(() => evaluateExpression('12 ÷ 0'), throwsFormatException);
    });
  });

  group('inverse generator', () {
    test('every generated expression evaluates to the target', () {
      final ex = generateInverseExpressions(12);
      expect(ex, isNotEmpty);
      for (final e in ex) {
        expect(
          (evaluateExpression(e) - 12).abs() < 1e-9,
          isTrue,
          reason: '"$e" should equal 12',
        );
      }
    });

    test('results are distinct and show operator variety', () {
      final ex = generateInverseExpressions(12); // default count is 6
      expect(ex, hasLength(6));
      final canon = ex.map(canonicalizeExpression).toSet();
      expect(canon, hasLength(ex.length), reason: 'no duplicates');

      // The pedagogical point: many DIFFERENT roads, not 6 additions.
      final ops = <String>{
        if (ex.any((e) => e.contains('×'))) '×',
        if (ex.any((e) => e.contains('+'))) '+',
        if (ex.any((e) => e.contains('−'))) '−',
        if (ex.any((e) => e.contains('÷'))) '÷',
      };
      expect(ops.length, greaterThanOrEqualTo(3), reason: 'variety leads: $ex');
    });
  });

  group('validator', () {
    test('valid, equal, novel for a fresh correct expression', () {
      final v = validateMathExpression('3×4', 12);
      expect(v.valid, isTrue);
      expect(v.equals, isTrue);
      expect(v.novel, isTrue);
      expect(v.value, 12);
    });

    test('novelty is canonical (spacing/glyphs ignored)', () {
      final v = validateMathExpression('3 × 4', 12, roomAnswers: {'3×4'});
      expect(v.novel, isFalse);

      final other = validateMathExpression('6+6', 12, roomAnswers: {'3×4'});
      expect(other.novel, isTrue);
      expect(other.equals, isTrue);
    });

    test('correct form but wrong value → valid, not equal', () {
      final v = validateMathExpression('5 + 5', 12);
      expect(v.valid, isTrue);
      expect(v.equals, isFalse);
      expect(v.value, 10);
    });

    test('malformed → not valid, null value', () {
      final v = validateMathExpression('3 +', 12);
      expect(v.valid, isFalse);
      expect(v.equals, isFalse);
      expect(v.value, isNull);
    });
  });

  group('phase runner', () {
    test('walks the Math activity present → create → reveal → ponder', () {
      final run = ActivityRun(mathInverseActivity(12));

      expect(run.current.mode, ActivityMode.present);
      expect(run.index, 0);
      expect(run.isAtEnd, isFalse);

      expect(run.advance(), isTrue);
      expect(run.current.mode, ActivityMode.create);
      expect(run.current.pacing, PacingKind.perLearner);

      expect(run.advance(), isTrue);
      expect(run.current.mode, ActivityMode.present); // the reveal

      expect(run.advance(), isTrue);
      expect(run.current.mode, ActivityMode.ponder);
      expect(run.current.pacing, PacingKind.timer);
      expect(run.current.duration, const Duration(seconds: 20));
      expect(run.isAtEnd, isTrue);

      // Clamped at the end — there is always a defined terminal phase.
      expect(run.advance(), isFalse);
      expect(run.isAtEnd, isTrue);

      run.restart();
      expect(run.index, 0);
    });

    test('per-learner runs advance independently (same script)', () {
      final activity = mathInverseActivity(7);
      final a = ActivityRun(activity)..advance();
      final b = ActivityRun(activity);

      expect(a.index, 1);
      expect(b.index, 0, reason: 'one learner moving must not move another');
    });
  });
}
