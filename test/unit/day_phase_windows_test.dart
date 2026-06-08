import 'package:differentworld/features/today/today_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configurable day-phase windows — the program-policy layer that lets a camp
/// or full-day program retime the whole "RIGHT NOW" lead system instead of
/// being stuck on afterschool hours.
void main() {
  DateTime at(int h, int m) => DateTime(2026, 6, 7, h, m);

  group('phaseAt', () {
    test('the afterschool defaults map the day', () {
      const w = DayPhaseWindows.afterschool;
      expect(w.phaseAt(at(12, 0)), DayPhase.prep);
      expect(w.phaseAt(at(14, 30)), DayPhase.arrival);
      expect(w.phaseAt(at(15, 45)), DayPhase.program);
      expect(w.phaseAt(at(16, 45)), DayPhase.pickup);
      expect(w.phaseAt(at(18, 30)), DayPhase.closed);
      expect(w.phaseAt(at(23, 0)), DayPhase.closed);
    });

    test('a camp window retimes the phases (noon is program, not prep)', () {
      const camp = DayPhaseWindows(
        arrivalStart: 9 * 60,
        programStart: 9 * 60 + 30,
        pickupStart: 15 * 60 + 30,
        closedStart: 16 * 60,
      );
      expect(camp.phaseAt(at(8, 0)), DayPhase.prep);
      expect(camp.phaseAt(at(9, 15)), DayPhase.arrival);
      // The afterschool defaults would call noon "prep" — the camp calls it
      // program. This is the whole point.
      expect(camp.phaseAt(at(12, 0)), DayPhase.program);
      expect(camp.phaseAt(at(15, 45)), DayPhase.pickup);
      expect(camp.phaseAt(at(16, 30)), DayPhase.closed);
    });
  });

  group('decode / encode', () {
    test('null / empty / corrupt / non-map fall back to afterschool', () {
      const def = DayPhaseWindows.afterschool;
      expect(decodePhaseWindows(null).arrivalStart, def.arrivalStart);
      expect(decodePhaseWindows('').programStart, def.programStart);
      expect(decodePhaseWindows('not json').pickupStart, def.pickupStart);
      expect(decodePhaseWindows('[1,2]').closedStart, def.closedStart);
    });

    test('round-trips a valid camp window', () {
      const camp = DayPhaseWindows(
        arrivalStart: 540,
        programStart: 570,
        pickupStart: 930,
        closedStart: 960,
      );
      final back = decodePhaseWindows(encodePhaseWindows(camp));
      expect(
        [back.arrivalStart, back.programStart, back.pickupStart, back.closedStart],
        [540, 570, 930, 960],
      );
    });

    test('forces the boundaries strictly ascending on out-of-order input', () {
      final w = decodePhaseWindows(
        '{"arrival":1000,"program":900,"pickup":800,"closed":700}',
      );
      expect(w.arrivalStart, 1000);
      expect(w.programStart, greaterThan(w.arrivalStart));
      expect(w.pickupStart, greaterThan(w.programStart));
      expect(w.closedStart, greaterThan(w.pickupStart));
    });

    test('partial JSON fills missing keys from defaults', () {
      const def = DayPhaseWindows.afterschool;
      final w = decodePhaseWindows('{"closed":1200}');
      expect(w.arrivalStart, def.arrivalStart);
      expect(w.closedStart, 1200);
    });
  });

  test('DayPhase.fromClock still matches the afterschool windows', () {
    // The fallback path delegates to the defaults — old behaviour preserved.
    expect(DayPhase.fromClock(at(12, 0)), DayPhase.prep);
    expect(DayPhase.fromClock(at(16, 0)), DayPhase.program);
    expect(DayPhase.fromClock(at(19, 0)), DayPhase.closed);
  });
}
