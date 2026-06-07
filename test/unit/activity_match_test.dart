// Pins the activity matcher (the brief's activity-matcher): verbs tagged
// in caps.action_verbs → activities matched to a kid's picks.

import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/activity_match.dart';
import 'package:flutter_test/flutter_test.dart';

Activity _activity(
  String name,
  List<String> verbs, {
  bool archived = false,
}) =>
    Activity(
      id: 'a-$name',
      spaceId: 's1',
      name: name,
      isOutdoor: 0,
      capabilities: jsonEncode({'action_verbs': verbs}),
      archivedAt: archived ? '2026-06-01T00:00:00Z' : null,
      createdAt: '2026-06-06T00:00:00Z',
      updatedAt: '2026-06-06T00:00:00Z',
    );

void main() {
  group('activityVerbs', () {
    test('reads tagged verbs and drops unknown ids', () {
      final a = _activity('Heavy Helper', ['carry', 'help', 'bogus']);
      expect(activityVerbs(a), ['carry', 'help']);
    });

    test('an untagged activity has no verbs', () {
      const a = Activity(
        id: 'x',
        spaceId: 's1',
        name: 'Plain',
        isOutdoor: 0,
        capabilities: '{}',
        createdAt: '2026-06-06T00:00:00Z',
        updatedAt: '2026-06-06T00:00:00Z',
      );
      expect(activityVerbs(a), isEmpty);
    });
  });

  group('matchActivities', () {
    final library = [
      _activity('Heavy Helper', ['carry', 'help', 'flow']), // 3-overlap
      _activity('Listen Up', ['listen', 'wait', 'watch']), // 1-overlap
      _activity('Build It', ['build', 'solve', 'spark']), // 0-overlap
      _activity('Carry Race', ['carry', 'play', 'shine']), // 1-overlap
      _activity('Old One', ['carry', 'help', 'listen'], archived: true),
    ];

    test('matches ≥1 shared verb, best overlap first, archived excluded', () {
      final m = matchActivities({'carry', 'help', 'listen'}, library);
      // Heavy Helper (2: carry,help) → Carry Race (1) & Listen Up (1).
      expect(m.first.activity.name, 'Heavy Helper');
      expect(m.first.overlap, 2);
      final names = m.map((x) => x.activity.name).toSet();
      expect(names, containsAll(['Heavy Helper', 'Carry Race', 'Listen Up']));
      expect(names, isNot(contains('Build It'))); // 0 overlap
      expect(names, isNot(contains('Old One'))); // archived
    });

    test('no picks-overlap → empty', () {
      final m = matchActivities({'echo'}, library);
      expect(m, isEmpty);
    });
  });
}
