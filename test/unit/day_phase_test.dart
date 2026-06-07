// Pins the afterschool DayPhase windows (docs/WORKFLOWS.md gap #1, wave 1).
// Pure clock → phase mapping; the boundaries are product decisions, so
// lock them so a refactor can't drift them silently.

import 'package:differentworld/features/today/today_providers.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int hour, int minute) => DateTime(2026, 6, 6, hour, minute);

void main() {
  group('DayPhase.fromClock — afterschool default windows', () {
    test('before 2:30p is prep', () {
      expect(DayPhase.fromClock(_at(0, 0)), DayPhase.prep);
      expect(DayPhase.fromClock(_at(9, 15)), DayPhase.prep);
      expect(DayPhase.fromClock(_at(14, 29)), DayPhase.prep);
    });

    test('2:30p–3:45p is arrival', () {
      expect(DayPhase.fromClock(_at(14, 30)), DayPhase.arrival);
      expect(DayPhase.fromClock(_at(15, 0)), DayPhase.arrival);
      expect(DayPhase.fromClock(_at(15, 44)), DayPhase.arrival);
    });

    test('3:45p–4:45p is program', () {
      expect(DayPhase.fromClock(_at(15, 45)), DayPhase.program);
      expect(DayPhase.fromClock(_at(16, 30)), DayPhase.program);
      expect(DayPhase.fromClock(_at(16, 44)), DayPhase.program);
    });

    test('4:45p–6:30p is pickup', () {
      expect(DayPhase.fromClock(_at(16, 45)), DayPhase.pickup);
      expect(DayPhase.fromClock(_at(17, 30)), DayPhase.pickup);
      expect(DayPhase.fromClock(_at(18, 29)), DayPhase.pickup);
    });

    test('6:30p and after is closed', () {
      expect(DayPhase.fromClock(_at(18, 30)), DayPhase.closed);
      expect(DayPhase.fromClock(_at(21, 0)), DayPhase.closed);
      expect(DayPhase.fromClock(_at(23, 59)), DayPhase.closed);
    });

    test('every boundary is covered with no gap (exhaustive minute sweep)', () {
      // Walk every minute of the day; assert a phase is always assigned
      // and that the sequence only ever moves forward prep→…→closed
      // (never skips backward), so the windows tile the day with no hole.
      var last = DayPhase.prep;
      for (var m = 0; m < 24 * 60; m++) {
        final phase = DayPhase.fromClock(_at(m ~/ 60, m % 60));
        expect(phase.index, greaterThanOrEqualTo(last.index),
            reason: 'phase went backward at minute $m');
        last = phase;
      }
      expect(last, DayPhase.closed);
    });
  });

  group('ArrivalProgress', () {
    test('mid-arrival reports who is still out', () {
      const p = ArrivalProgress(inBuilding: 12, total: 18);
      expect(p.stillOut, 6);
      expect(p.allIn, isFalse);
    });

    test('everyone in → allIn, none out', () {
      const p = ArrivalProgress(inBuilding: 18, total: 18);
      expect(p.stillOut, 0);
      expect(p.allIn, isTrue);
    });

    test('over-count (data race) clamps and never goes negative', () {
      const p = ArrivalProgress(inBuilding: 20, total: 18);
      expect(p.stillOut, 0);
      expect(p.allIn, isTrue);
    });

    test('empty roster is not "all in"', () {
      const p = ArrivalProgress(inBuilding: 0, total: 0);
      expect(p.allIn, isFalse);
      expect(p.stillOut, 0);
    });
  });
}
