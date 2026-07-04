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

    group(
      'off-schedule bends the clock — a live field trip wins over phase',
      () {
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
      },
    );

    test('a non-trip live block does NOT override the phase', () {
      expect(
        computeCockpitBeat(
          phase: DayPhase.program,
          liveBlockKind: BlockKind.onSite,
        ),
        CockpitBeat.now,
      );
    });

    test('reveal is not auto-selected without the closing window', () {
      for (final phase in DayPhase.values) {
        for (final sendable in [true, false]) {
          expect(
            // closingReveal defaults to false.
            computeCockpitBeat(phase: phase, sendable: sendable),
            isNot(CockpitBeat.reveal),
          );
        }
      }
    });

    group('slice 2 — the closing window flips program to the reveal', () {
      test('program + closingReveal → reveal', () {
        expect(
          computeCockpitBeat(phase: DayPhase.program, closingReveal: true),
          CockpitBeat.reveal,
        );
      });

      test('a live field trip still wins over the closing window', () {
        expect(
          computeCockpitBeat(
            phase: DayPhase.program,
            liveBlockKind: BlockKind.fieldTrip,
            closingReveal: true,
          ),
          CockpitBeat.fieldTrip,
        );
      });

      test('closingReveal only affects program — other phases ignore it', () {
        expect(
          computeCockpitBeat(phase: DayPhase.prep, closingReveal: true),
          CockpitBeat.gettingReady,
        );
        expect(
          computeCockpitBeat(phase: DayPhase.arrival, closingReveal: true),
          CockpitBeat.goodMorning,
        );
        expect(
          computeCockpitBeat(phase: DayPhase.pickup, closingReveal: true),
          CockpitBeat.pickup,
        );
        expect(
          computeCockpitBeat(phase: DayPhase.closed, closingReveal: true),
          CockpitBeat.closed,
        );
      });
    });
  });
}
