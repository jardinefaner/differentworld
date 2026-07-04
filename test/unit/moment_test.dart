// Pins the Story moment-mapper: every entry kind → a story beat (or null
// for logistics).

import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _e(
  String kind, {
  String? body,
  Map<String, dynamic> details = const {},
}) => Entry(
  id: 'e-$kind',
  spaceId: 's1',
  kind: kind,
  details: jsonEncode(details),
  recordedBy: 'm1',
  recordedAt: '2026-06-06T15:00:00Z',
  updatedAt: '2026-06-06T15:00:00Z',
  subjectId: 'kid1',
  body: body,
);

void main() {
  test('observation → a note beat with photos', () {
    final m = momentFor(_e('observation', body: 'Built a tall tower.'))!;
    expect(m.emoji, '📝');
    expect(m.body, 'Built a tall tower.');
    expect(m.showsPhotos, isTrue);
  });

  test('action_words → the world + practiced verbs', () {
    final m = momentFor(
      _e(
        'action_words',
        details: {
          'verb_picks': ['watch', 'spark', 'shine'],
        },
      ),
    )!;
    expect(m.emoji, '🦅'); // Eagle
    expect(m.title, 'Was Eagle');
    expect(m.body, 'Practiced watch, spark, shine');
  });

  test('mission → did the mission', () {
    final m = momentFor(
      _e('mission', details: {'missionName': 'Plant Helper'}),
    )!;
    expect(m.emoji, '🎯');
    expect(m.title, 'Did: Plant Helper');
  });

  test('role → was the role, with its emoji', () {
    final m = momentFor(
      _e('role', details: {'role_name': 'Bee', 'emoji': '🐝'}),
    )!;
    expect(m.emoji, '🐝');
    expect(m.title, 'Was a Bee');
  });

  test('incident → the type + narrative', () {
    final m = momentFor(
      _e(
        'incident',
        body: 'Scraped a knee.',
        details: {'incident_type': 'injury', 'parent_notified': false},
      ),
    )!;
    expect(m.emoji, '⚠️');
    expect(m.title, 'Injury / bump logged');
    expect(m.body, 'Scraped a knee.');
  });

  test('care kinds map to icons', () {
    expect(momentFor(_e('meal'))!.emoji, '🍎');
    expect(momentFor(_e('nap'))!.emoji, '😴');
  });

  test('a departure is logistics, not a story beat', () {
    expect(momentFor(_e('departure')), isNull);
  });

  test('momentsFrom weaves entries and drops the non-beats', () {
    final moments = momentsFrom([
      _e('observation', body: 'A note.'),
      _e('departure'),
      _e('meal'),
    ]);
    expect(moments.length, 2); // departure dropped
    expect(moments.map((m) => m.emoji), ['📝', '🍎']);
  });
}
