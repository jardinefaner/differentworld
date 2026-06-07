// Smoke-tests the incident report PDF builder (wave A): it renders valid,
// non-empty PDF bytes offline (the `pdf` package is pure Dart — no
// platform binding, no network font fetch).

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/features/incidents/templates/incident_report.dart';
import 'package:flutter_test/flutter_test.dart';

Incident _inc(
  String type,
  bool notified, {
  String? action,
  String narrative = '',
}) =>
    Incident.fromEntry(
      Entry(
        id: 'e-$type',
        spaceId: 's1',
        kind: 'incident',
        details: incidentDetailsJson(
          incidentType: type,
          parentNotified: notified,
          actionTaken: action,
        ),
        recordedBy: 'm1',
        recordedAt: '2026-06-06T17:00:00Z',
        updatedAt: '2026-06-06T17:00:00Z',
        body: narrative,
      ),
    );

void main() {
  test('renders a valid non-empty PDF with the notified count', () async {
    final data = IncidentReportData(
      entries: [
        IncidentReportEntry(
          incident: _inc('injury', true,
              action: 'Ice applied', narrative: 'Scraped a knee.'),
          childName: 'Amy Apple',
        ),
        IncidentReportEntry(
          incident: _inc('conflict', false, narrative: 'A pushing match.'),
          childName: 'Ben Banana',
        ),
      ],
      spaceName: 'Sunny Afterschool',
      title: 'Incident report',
      generatedAt: DateTime(2026, 6, 6, 17, 0),
    );
    expect(data.notifiedCount, 1);

    final bytes = await (await buildIncidentReportPdf(data)).save();
    expect(bytes.length, greaterThan(500));
    // Every PDF starts with the "%PDF" magic.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('an empty report still renders (no crash)', () async {
    final data = IncidentReportData(
      entries: const [],
      spaceName: null,
      title: 'Incident report',
      generatedAt: DateTime(2026, 6, 6),
    );
    final bytes = await (await buildIncidentReportPdf(data)).save();
    expect(bytes.length, greaterThan(100));
  });
}
