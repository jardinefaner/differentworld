import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The contextual lead's whole promise: show ONLY the immediate utility for
/// the current moment. These pin the reveal logic — especially the
/// field-trip → vehicle case (the vertical slice) and the ≤1-primary-+-≤2-chip
/// minimalism — so a future edit can't quietly turn the lead back into a wall.
void main() {
  group('computeContextLead', () {
    test('a signed-in non-logger gets no lead (family lens instead)', () {
      expect(
        computeContextLead(
          isLogger: false,
          phase: DayPhase.program,
          kidsLabel: 'kids',
        ),
        isNull,
      );
    });

    test('closed for the day → no lead', () {
      expect(
        computeContextLead(
          isLogger: true,
          phase: DayPhase.closed,
          kidsLabel: 'kids',
        ),
        isNull,
      );
    });

    test('a live field trip reveals the vehicle as the primary move', () {
      final lead = computeContextLead(
        isLogger: true,
        phase: DayPhase.program,
        kidsLabel: 'kids',
        live: (
          blockId: 'b1',
          groupId: 'g1',
          title: 'Nature center',
          kind: BlockKind.fieldTrip,
          isOutdoor: false,
        ),
      );
      expect(lead, isNotNull);
      expect(lead!.tone, ContextTone.trip);
      expect(lead.title, 'Nature center');
      expect(lead.primary.label, 'Check out vehicle');
      expect(lead.primary.route, '/vehicles');
      // Ruthless: the trip roster is the ONLY secondary move.
      expect(lead.more, hasLength(1));
      expect(lead.more.single.route, '/trips/b1');
    });

    test('a running activity with a curriculum world leads with the run', () {
      final lead = computeContextLead(
        isLogger: true,
        phase: DayPhase.program,
        kidsLabel: 'kids',
        live: (
          blockId: 'b2',
          groupId: 'g2',
          title: 'STEM lab',
          kind: BlockKind.onSite,
          isOutdoor: false,
        ),
        worldName: 'Through My Eyes',
      );
      expect(lead!.tone, ContextTone.go);
      expect(lead.primary.route, '/play-today');
      expect(
        lead.more.map((m) => m.route),
        contains('/groups/g2/attendance'),
      );
    });

    test('an activity with no world falls back to capture (no duplicate)', () {
      final lead = computeContextLead(
        isLogger: true,
        phase: DayPhase.program,
        kidsLabel: 'kids',
        live: (
          blockId: 'b3',
          groupId: 'g3',
          title: 'Free play',
          kind: BlockKind.onSite,
          isOutdoor: false,
        ),
      );
      expect(lead!.primary.route, '/captures/new');
      // No world → no "Observe" chip duplicating the primary; attendance only.
      expect(lead.more, hasLength(1));
      expect(lead.more.single.route, '/groups/g3/attendance');
    });

    test('an outdoor activity leads with a head count, run drops to a chip', () {
      final lead = computeContextLead(
        isLogger: true,
        phase: DayPhase.program,
        kidsLabel: 'kids',
        live: (
          blockId: 'b4',
          groupId: 'g4',
          title: 'Playground',
          kind: BlockKind.onSite,
          isOutdoor: true,
        ),
        worldName: 'Through My Eyes',
      );
      expect(lead!.eyebrow, 'OUTSIDE');
      expect(lead.primary.label, 'Head count');
      expect(lead.primary.route, '/groups/g4/attendance');
      // Even with a world live, the run is secondary outdoors — headcount wins.
      expect(lead.more.single.route, '/play-today');
    });

    test('arrival (no live block) leads with check-in + a headcount line', () {
      final lead = computeContextLead(
        isLogger: true,
        phase: DayPhase.arrival,
        kidsLabel: 'kids',
        arrival: (total: 18, inBuilding: 5, stillOut: 13, allIn: false),
      );
      expect(lead!.primary.route, '/checklist?filter=unmarked');
      expect(lead.line, contains('5 of 18'));
      expect(lead.more, isEmpty); // one move only at arrival
    });

    test('pickup leads with the release board', () {
      final lead = computeContextLead(
        isLogger: true,
        phase: DayPhase.pickup,
        kidsLabel: 'kids',
      );
      expect(lead!.tone, ContextTone.pickup);
      expect(lead.primary.route, '/pickup');
    });

    test('downtime (no live block) leads with an activity', () {
      final lead = computeContextLead(
        isLogger: true,
        phase: DayPhase.program,
        kidsLabel: 'kids',
      );
      // A teacher's "what now?" in a gap → an activity is the lead move
      // ("if you want an activity, it's here"); capture + schedule drop to
      // the secondary moves.
      expect(lead!.primary.route, '/breaks');
      expect(lead.primary.label, 'Pick an activity');
      expect(
        lead.more.map((m) => m.route),
        containsAll(<String>['/captures/new', '/schedule']),
      );
    });

    test('program-gap gives a director Insights as a second chip', () {
      final lead = computeContextLead(
        isLogger: true,
        phase: DayPhase.program,
        kidsLabel: 'kids',
        isDirector: true,
      );
      expect(
        lead!.more.map((m) => m.route),
        containsAll(<String>['/schedule', '/insights']),
      );
    });
  });
}
