// Pins the Story wrap roll-up (the daily/weekly highlight).

import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/story/wrap.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _e(
  String kind, {
  String? body,
  Map<String, dynamic> details = const {},
  String recordedAt = '2026-06-05T15:00:00Z',
}) => Entry(
  id: 'e-$kind-$recordedAt',
  spaceId: 's1',
  kind: kind,
  details: jsonEncode(details),
  recordedBy: 'm1',
  recordedAt: recordedAt,
  updatedAt: recordedAt,
  subjectId: 'kid1',
  body: body,
);

void main() {
  test('buildWrap rolls worlds, top verbs, missions, notes + prose', () {
    final entries = [
      _e(
        'action_words',
        details: {
          'verb_picks': ['play', 'echo', 'flow'],
          'done': ['play', 'echo', 'flow'],
        },
      ), // Dolphin
      _e(
        'action_words',
        details: {
          'verb_picks': ['play', 'help', 'shine'],
        },
      ), // Dog
      _e('mission', details: {'missionName': 'Plant Helper'}),
      _e('observation', body: 'Built a tall tower.'),
      _e('departure'), // dropped from momentCount
    ];
    final wrap = buildWrap(
      subjectName: 'Maya',
      periodLabel: 'This week',
      entries: entries,
      cutoff: DateTime(2026, 6),
    );

    expect(wrap.worlds, containsAll(['🐬 Dolphin', '🐶 Dog']));
    expect(wrap.topVerbs.first, 'play'); // practiced twice
    expect(wrap.missions, ['Plant Helper']);
    expect(wrap.highlights, ['Built a tall tower.']);
    expect(wrap.momentCount, 4); // departure not a moment
    expect(wrap.text, contains('Maya was'));
    expect(wrap.text, contains('Practiced play'));
    expect(wrap.text, contains('Did Plant Helper.'));
    expect(wrap.text, contains('“Built a tall tower.”'));
  });

  test('entries before the cutoff are excluded', () {
    final wrap = buildWrap(
      subjectName: 'Ben',
      periodLabel: 'Today',
      entries: [
        _e(
          'observation',
          body: 'Old note.',
          recordedAt: '2026-05-01T15:00:00Z',
        ),
      ],
      cutoff: DateTime(2026, 6),
    );
    expect(wrap.isEmpty, isTrue);
    expect(wrap.text, contains('a quiet one'));
  });
}
