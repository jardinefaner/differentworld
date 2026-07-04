// Pins the structured-incident parse (docs/WORKFLOWS.md gap #3):
// Incident.fromEntry reads the narrative off entry.body and the typed
// fields out of details JSON, and degrades safely on bad/missing data.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry({required String details, String? body}) => Entry(
  id: 'e1',
  spaceId: 'space-1',
  kind: 'incident',
  details: details,
  recordedBy: 'm1',
  recordedAt: '2026-06-06T16:00:00Z',
  updatedAt: '2026-06-06T16:00:00Z',
  subjectId: 's1',
  groupId: 'g1',
  body: body,
);

void main() {
  group('IncidentType.fromId', () {
    test('known ids resolve; unknown / null fall back to other', () {
      expect(IncidentType.fromId('injury'), IncidentType.injury);
      expect(IncidentType.fromId('conflict'), IncidentType.conflict);
      expect(IncidentType.fromId('medical'), IncidentType.medical);
      expect(IncidentType.fromId('not-a-real-type'), IncidentType.other);
      expect(IncidentType.fromId(null), IncidentType.other);
    });
  });

  group('Incident.fromEntry', () {
    test('parses type, narrative, action, and parent_notified', () {
      final incident = Incident.fromEntry(
        _entry(
          body: '  Tripped on the step, scraped a knee.  ',
          details:
              '{"incident_type":"injury","action_taken":"Cleaned and bandaged.","parent_notified":true}',
        ),
      );
      expect(incident.type, IncidentType.injury);
      expect(incident.narrative, 'Tripped on the step, scraped a knee.');
      expect(incident.actionTaken, 'Cleaned and bandaged.');
      expect(incident.parentNotified, isTrue);
      expect(incident.subjectId, 's1');
    });

    test('missing parent_notified is false; missing action is null', () {
      final incident = Incident.fromEntry(
        _entry(
          body: 'Pushed during a game.',
          details: '{"incident_type":"conflict"}',
        ),
      );
      expect(incident.type, IncidentType.conflict);
      expect(incident.parentNotified, isFalse);
      expect(incident.actionTaken, isNull);
    });

    test('malformed details JSON degrades to other / not-notified', () {
      final incident = Incident.fromEntry(
        _entry(body: 'Something happened.', details: 'not json at all'),
      );
      expect(incident.type, IncidentType.other);
      expect(incident.parentNotified, isFalse);
      expect(incident.actionTaken, isNull);
      expect(incident.narrative, 'Something happened.');
    });

    test('null body → empty narrative (no crash)', () {
      final incident = Incident.fromEntry(_entry(details: '{}'));
      expect(incident.narrative, '');
      expect(incident.type, IncidentType.other);
    });
  });

  group('incidentDetailsJson ↔ Incident.fromEntry', () {
    test('encodes a shape that parses back identically', () {
      final json = incidentDetailsJson(
        incidentType: 'medical',
        actionTaken: 'EpiPen administered',
        parentNotified: true,
      );
      final inc = Incident.fromEntry(
        _entry(body: 'Allergic reaction', details: json),
      );
      expect(inc.type, IncidentType.medical);
      expect(inc.actionTaken, 'EpiPen administered');
      expect(inc.parentNotified, isTrue);
    });

    test('mark-notified amend flips only the flag, preserving type+action', () {
      final logged = Incident.fromEntry(
        _entry(
          body: 'Bumped head',
          details: incidentDetailsJson(
            incidentType: 'injury',
            actionTaken: 'Ice applied',
            parentNotified: false,
          ),
        ),
      );
      expect(logged.parentNotified, isFalse);

      // The amend rebuilds the details from the parsed incident.
      final amended = Incident.fromEntry(
        _entry(
          body: 'Bumped head',
          details: incidentDetailsJson(
            incidentType: logged.type.id,
            actionTaken: logged.actionTaken,
            parentNotified: true,
          ),
        ),
      );
      expect(amended.parentNotified, isTrue);
      expect(amended.type, IncidentType.injury);
      expect(amended.actionTaken, 'Ice applied');
    });
  });

  group('family visibility (the leak-proof policy)', () {
    Incident incidentWith({
      required bool notified,
      String? familyNote,
      String narrative = 'Internal: pushed by another child.',
    }) => Incident.fromEntry(
      _entry(
        body: narrative,
        details: incidentDetailsJson(
          incidentType: 'conflict',
          parentNotified: notified,
          familyNote: familyNote,
        ),
      ),
    );

    test('a surfaced incident (notified OR family note) is family-visible', () {
      expect(incidentWith(notified: true).familyVisible, isTrue);
      expect(
        incidentWith(
          notified: false,
          familyNote: 'We spoke with you today.',
        ).familyVisible,
        isTrue,
      );
      expect(
        incidentWith(
          notified: true,
          familyNote: 'Details shared.',
        ).familyVisible,
        isTrue,
      );
    });

    test('an un-surfaced incident stays internal-only', () {
      expect(incidentWith(notified: false).familyVisible, isFalse);
      expect(incidentWith(notified: false).familyNote, isNull);
    });

    test('family note round-trips; narrative stays separate (staff-only)', () {
      final inc = incidentWith(
        notified: false,
        familyNote: '  Amy bumped her knee; she is fine.  ',
        narrative: 'Tussle with Ben over a toy.',
      );
      expect(inc.familyNote, 'Amy bumped her knee; she is fine.');
      // The internal narrative is preserved separately and is NOT the
      // family note — the family card only ever reads familyNote.
      expect(inc.narrative, 'Tussle with Ben over a toy.');
      expect(inc.familyNote == inc.narrative, isFalse);
    });
  });
}
