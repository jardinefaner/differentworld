// Pins the room-added-rules contract (the "add a rule" delete path): the
// pure mapper must carry each entry's id (so the room can delete its own
// rules), keep only THIS world's non-empty rules, and degrade on bad data.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _rule({
  required String id,
  required String worldId,
  String? body,
}) => Entry(
      id: id,
      spaceId: 'space-1',
      kind: 'world_rule',
      details: '{"world_id":"$worldId"}',
      recordedBy: 'm1',
      recordedAt: '2026-06-06T16:00:00Z',
      updatedAt: '2026-06-06T16:00:00Z',
      body: body,
    );

void main() {
  group('addedWorldRulesFrom', () {
    test('keeps this world non-empty rules, carrying the entry id', () {
      final entries = [
        _rule(id: 'r1', worldId: 'water', body: 'We clean up together'),
        _rule(id: 'r2', worldId: 'space', body: 'Other world'), // filtered out
        _rule(id: 'r3', worldId: 'water', body: '   '), // empty → dropped
        _rule(id: 'r4', worldId: 'water', body: 'Share the cascade'),
      ];

      final rules = addedWorldRulesFrom(entries, 'water');

      // Ids carried (the whole point — the UI deletes by id).
      expect(rules.map((r) => r.id).toList(), ['r1', 'r4']);
      expect(
        rules.map((r) => r.text).toList(),
        ['We clean up together', 'Share the cascade'],
      );
    });

    test('trims the text', () {
      final rules = addedWorldRulesFrom(
        [_rule(id: 'r1', worldId: 'water', body: '  take the shape  ')],
        'water',
      );
      expect(rules.single, (id: 'r1', text: 'take the shape'));
    });

    test('drops entries with malformed details', () {
      const bad = Entry(
        id: 'b1',
        spaceId: 'space-1',
        kind: 'world_rule',
        details: 'not json',
        recordedBy: 'm1',
        recordedAt: '2026-06-06T16:00:00Z',
        updatedAt: '2026-06-06T16:00:00Z',
        body: 'orphan rule',
      );
      expect(addedWorldRulesFrom([bad], 'water'), isEmpty);
    });
  });
}
