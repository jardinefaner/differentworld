import 'package:differentworld/features/cockpit/cockpit_beat.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeCockpitBeat — the clock chooses the one beat', () {
    test('prep → getting ready', () {
      expect(
        computeCockpitBeat(phase: DayPhase.prep),
        CockpitBeat.gettingReady,
      );
    });

    test('arrival → good morning', () {
      expect(
        computeCockpitBeat(phase: DayPhase.arrival),
        CockpitBeat.goodMorning,
      );
    });

    test('program → now', () {
      expect(
        computeCockpitBeat(phase: DayPhase.program),
        CockpitBeat.now,
      );
    });

    test('pickup → pickup', () {
      expect(
        computeCockpitBeat(phase: DayPhase.pickup),
        CockpitBeat.pickup,
      );
    });

    test('closed + kids today → send', () {
      expect(
        computeCockpitBeat(phase: DayPhase.closed, sendable: true),
        CockpitBeat.send,
      );
    });

    test('closed + nothing to send → the day at rest', () {
      expect(
        // sendable defaults to false — the rest state.
        computeCockpitBeat(phase: DayPhase.closed),
        CockpitBeat.closed,
      );
    });

    group('off-schedule bends the clock — a live field trip wins over phase', () {
      for (final phase in DayPhase.values) {
        test('$phase + a field-trip block → fieldTrip', () {
          expect(
            computeCockpitBeat(
              phase: phase,
              liveBlockKind: BlockKind.fieldTrip,
            ),
            CockpitBeat.fieldTrip,
          );
        });
      }
    });

    test('a non-trip live block does NOT override the phase', () {
      expect(
        computeCockpitBeat(
          phase: DayPhase.program,
          liveBlockKind: BlockKind.onSite,
        ),
        CockpitBeat.now,
      );
    });

    test('reveal is never auto-selected (slice 1 — reached by the beat rail)', () {
      for (final phase in DayPhase.values) {
        for (final sendable in [true, false]) {
          expect(
            computeCockpitBeat(phase: phase, sendable: sendable),
            isNot(CockpitBeat.reveal),
          );
        }
      }
    });
  });
}
