import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/world/skill_measure.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Skills data layer — the one genuinely-new piece of the RPG synthesis.
/// Measurements parse, the latest + previous resolve by time (the delta the
/// character sheet shows), and each skill formats its own unit.
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
        details: '{"skill":"stillness","value":47}',
        at: '2026-07-01T09:00:00Z',
      ),
    );
    expect(m, isNotNull);
    expect(m!.skillId, 'stillness');
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
          details: '{"skill":"stillness","value":47}',
          at: '2026-07-15T09:00:00Z',
        ),
        _entry(
          kind: EntryKind.skillMeasure,
          details: '{"skill":"stillness","value":12}',
          at: '2026-07-01T09:00:00Z',
        ),
        _entry(
          kind: EntryKind.skillMeasure,
          details: '{"skill":"stillness","value":34}',
          at: '2026-07-08T09:00:00Z',
        ),
        _entry(
          kind: EntryKind.skillMeasure,
          details: '{"skill":"words","value":3}',
          at: '2026-07-02T09:00:00Z',
        ),
      ];
      final p = latestSkillValues(entries);
      expect(p['stillness']!.latest, 47); // newest
      expect(p['stillness']!.previous, 34); // the one before → delta +13
      expect(p['words']!.latest, 3);
      expect(p['words']!.previous, isNull); // only one measure
    },
  );

  test('each skill formats its own unit', () {
    expect(measurableSkillById('stillness')!.format(47), '47s');
    expect(measurableSkillById('depth')!.format(4), '4/5');
    expect(measurableSkillById('words')!.format(8), '8 words');
  });

  test('the five measurable skills exist', () {
    expect(
      kMeasurableSkills.map((s) => s.id),
      containsAll(<String>['stillness', 'story', 'words', 'details', 'depth']),
    );
  });
}
