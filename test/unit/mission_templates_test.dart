// The starter mission catalog + the actions JSON codec (docs/MISSIONS.md).
// Each template is a real job with a manual, a practiceable checklist, the
// evidence it leaves, and an age range.

import 'package:differentworld/features/missions/mission_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('missionTemplates', () {
    test('ships a healthy starter set with unique names', () {
      expect(missionTemplates.length, greaterThanOrEqualTo(10));
      final names = missionTemplates.map((t) => t.name).toSet();
      expect(names, hasLength(missionTemplates.length), reason: 'unique');
      // The two the user named explicitly are present.
      expect(names, containsAll(<String>['Equipment Manager', 'Snack Helper']));
    });

    test('every template has an icon, a manual, steps, and a trait', () {
      for (final t in missionTemplates) {
        expect(t.icon.trim(), isNotEmpty, reason: '${t.name} icon');
        expect(t.builds.trim(), isNotEmpty, reason: '${t.name} builds');
        expect(t.rules.trim(), isNotEmpty, reason: '${t.name} rules/manual');
        expect(t.actions, isNotEmpty, reason: '${t.name} actions');
        for (final a in t.actions) {
          expect(a.trim(), isNotEmpty, reason: '${t.name} step');
        }
      }
    });

    test('age ranges are sane when set', () {
      for (final t in missionTemplates) {
        final lo = t.minAge;
        final hi = t.maxAge;
        if (lo != null && hi != null) {
          expect(lo, lessThanOrEqualTo(hi), reason: t.name);
        }
      }
    });
  });

  group('actions codec', () {
    test('round-trips a list of steps', () {
      const steps = ['Count the balls', 'Wipe them down', 'Put them away'];
      final encoded = encodeMissionActions(steps);
      expect(decodeMissionActions(encoded), steps);
    });

    test('encode drops blank steps', () {
      final encoded = encodeMissionActions(['a', '  ', '', 'b']);
      expect(decodeMissionActions(encoded), ['a', 'b']);
    });

    test('decode is tolerant of null / blank / malformed', () {
      expect(decodeMissionActions(null), isEmpty);
      expect(decodeMissionActions(''), isEmpty);
      expect(decodeMissionActions('not json'), isEmpty);
      expect(decodeMissionActions('{"not":"a list"}'), isEmpty);
    });
  });

  group('MissionEvidenceKind', () {
    test('fromKey resolves known keys and defaults to check', () {
      expect(MissionEvidenceKind.fromKey('photo'), MissionEvidenceKind.photo);
      expect(MissionEvidenceKind.fromKey('count'), MissionEvidenceKind.count);
      expect(MissionEvidenceKind.fromKey(null), MissionEvidenceKind.check);
      expect(MissionEvidenceKind.fromKey('bogus'), MissionEvidenceKind.check);
    });
  });
}
