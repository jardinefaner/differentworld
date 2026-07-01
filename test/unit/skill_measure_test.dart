import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/world/skill_measure.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Skills data layer — the ledger under the 60-skill catalog. Measurements
/// parse, the latest + previous resolve by time (the delta the character sheet
/// shows), and each skill formats its own unit. The catalog is now DERIVED from
/// the canonical `verb_skills.dart` (60 skills), so ids read like 'wait.still'.
Entry _entry({
  required String kind,
  required String details,
  required String at,
}) => Entry(
  id: at,
  spaceId: 's',
  kind: kind,
  details: details,
  recordedBy: 'm',
  recordedAt: at,
  updatedAt: at,
  subjectId: 'kid',
  groupId: 'g',
);

void main() {
  test('fromEntry parses a measure; rejects other kinds + bad json', () {
    final m = SkillMeasure.fromEntry(
      _entry(
        kind: EntryKind.skillMeasure,
        details: '{"skill":"wait.still","value":47}',
        at: '2026-07-01T09:00:00Z',
      ),
    );
    expect(m, isNotNull);
    expect(m!.skillId, 'wait.still');
    expect(m.value, 47);

    expect(
      SkillMeasure.fromEntry(
        _entry(kind: EntryKind.mood, details: '{"value":3}', at: '2026-07-01'),
      ),
      isNull,
    );
    expect(
      SkillMeasure.fromEntry(
        _entry(kind: EntryKind.skillMeasure, details: 'nope', at: '2026-07-01'),
      ),
      isNull,
    );
  });

  test(
    'latestSkillValues finds latest + previous by time (not list order)',
    () {
      // Deliberately out of order — the function must sort by recordedAt.
      final entries = [
        _entry(
          kind: EntryKind.skillMeasure,
          details: '{"skill":"wait.still","value":47}',
          at: '2026-07-15T09:00:00Z',
        ),
        _entry(
          kind: EntryKind.skillMeasure,
          details: '{"skill":"wait.still","value":12}',
          at: '2026-07-01T09:00:00Z',
        ),
        _entry(
          kind: EntryKind.skillMeasure,
          details: '{"skill":"wait.still","value":34}',
          at: '2026-07-08T09:00:00Z',
        ),
        _entry(
          kind: EntryKind.skillMeasure,
          details: '{"skill":"listen.count","value":3}',
          at: '2026-07-02T09:00:00Z',
        ),
      ];
      final p = latestSkillValues(entries);
      expect(p['wait.still']!.latest, 47); // newest
      expect(p['wait.still']!.previous, 34); // the one before → delta +13
      expect(p['listen.count']!.latest, 3);
      expect(p['listen.count']!.previous, isNull); // only one measure
    },
  );

  test('each skill formats its own unit (from its measure)', () {
    expect(measurableSkillById('wait.still')!.format(47), '47s'); // seconds
    expect(measurableSkillById('carry.steady')!.format(4), '4/5'); // rating
    expect(measurableSkillById('listen.count')!.format(8), '8'); // count → bare
    expect(measurableSkillById('carry.deliver')!.format(3), '3/day'); // freq
  });

  test('the catalog is the canonical 60, derived from verb_skills', () {
    expect(kMeasurableSkills.length, 60);
    expect(
      kMeasurableSkills.map((s) => s.id),
      containsAll(<String>['wait.still', 'carry.lift', 'shine.stand']),
    );
    // The emoji rides in from the verb.
    expect(measurableSkillById('carry.lift')!.emoji, '📦');
  });
}
