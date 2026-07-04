import 'package:differentworld/features/schedule/nudge.dart';
import 'package:flutter_test/flutter_test.dart';

NudgeSlot _s(String id, int min, double e, {bool fixed = false}) =>
    (id: id, title: id, emoji: '•', minutes: min, energy: e, fixed: fixed);

int _total(NudgePlan p) => p.ordered.fold(0, (a, b) => a + b.minutes);

void main() {
  group('recomposeNudge', () {
    test('behind compresses flexible blocks to fit, keeps fixed', () {
      final r = [
        _s('a', 45, .8),
        _s('b', 30, .9),
        _s('pickup', 15, .2, fixed: true),
      ];
      // total 90; available 70 → flex (75) must fit into (70-15=55).
      final p = recomposeNudge(r, 70, NudgeIntent.behind, endLabel: '6:00');
      expect(p.isNoop, isFalse);
      expect(p.ordered.firstWhere((s) => s.id == 'pickup').minutes, 15);
      final flex = p.ordered
          .where((s) => !s.fixed)
          .fold<int>(0, (a, b) => a + b.minutes);
      expect(flex, lessThanOrEqualTo(55));
      expect(_total(p), lessThan(90)); // the day got tighter
    });

    test('behind is a no-op when already inside the window', () {
      final r = [_s('a', 20, .8), _s('b', 15, .5)];
      expect(recomposeNudge(r, 60, NudgeIntent.behind).isNoop, isTrue);
    });

    test('ahead stretches the first flexible block by the surplus', () {
      final r = [_s('a', 30, .8), _s('pickup', 15, .2, fixed: true)];
      // total 45; available 60 → surplus 15 to 'a'.
      final p = recomposeNudge(r, 60, NudgeIntent.ahead);
      expect(p.ordered.firstWhere((s) => s.id == 'a').minutes, 45);
      expect(p.ordered.firstWhere((s) => s.id == 'pickup').minutes, 15);
    });

    test('ahead is a no-op when there is no surplus', () {
      final r = [_s('a', 45, .8), _s('b', 30, .9)];
      expect(recomposeNudge(r, 60, NudgeIntent.ahead).isNoop, isTrue);
    });

    test('wired brings the next calm block forward, durations unchanged', () {
      final r = [
        _s('active', 30, .9),
        _s('snack', 15, .3),
        _s('outdoor', 30, .9),
      ];
      final p = recomposeNudge(r, 90, NudgeIntent.wired);
      expect(p.ordered.first.id, 'snack');
      expect(p.isNoop, isFalse);
      expect(_total(p), 75); // nothing shrank
    });

    test('wired is a no-op when the next block is already calm', () {
      final r = [_s('calm', 15, .2), _s('a', 30, .9)];
      expect(recomposeNudge(r, 90, NudgeIntent.wired).isNoop, isTrue);
    });

    test('wired is a no-op when nothing calm remains', () {
      final r = [_s('a', 30, .9), _s('b', 30, .8)];
      expect(recomposeNudge(r, 90, NudgeIntent.wired).isNoop, isTrue);
    });

    test('behind survives a sub-5-minute block (no clamp RangeError)', () {
      final r = [
        _s('transition', 3, .5),
        _s('a', 45, .8),
        _s('pickup', 15, .2, fixed: true),
      ];
      // total 63; available 40 → compress. The 3-min block can't go below 3
      // (its own duration is the floor when < 5) — and must not throw.
      final p = recomposeNudge(r, 40, NudgeIntent.behind);
      expect(p.ordered.firstWhere((s) => s.id == 'transition').minutes, 3);
      expect(p.isNoop, isFalse);
    });

    test('empty remaining is safe', () {
      expect(recomposeNudge(const [], 60, NudgeIntent.behind).ordered, isEmpty);
    });
  });
}
