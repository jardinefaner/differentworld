// The animal & nature role catalog (docs/ROLES_SMART_PRACTICE.md). A role
// is a SMART daily practice: exactly 3 habits + 3 artifacts + a trait.

import 'package:differentworld/features/activity_runtime/roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roleCatalog', () {
    test('is the full curated set with unique fingerprints', () {
      expect(roleCatalog.length, greaterThanOrEqualTo(20));
      final fingerprints = roleCatalog.map((r) => r.fingerprint).toSet();
      expect(
        fingerprints,
        hasLength(roleCatalog.length),
        reason: 'fingerprints must be unique (the de-dupe key)',
      );
    });

    test('every role has exactly 3 habits + 3 artifacts, all non-empty', () {
      for (final r in roleCatalog) {
        expect(r.habits, hasLength(3), reason: '${r.name} habits');
        expect(r.artifacts, hasLength(3), reason: '${r.name} artifacts');
        expect(r.emoji.trim(), isNotEmpty, reason: '${r.name} emoji');
        expect(r.builds.trim(), isNotEmpty, reason: '${r.name} builds');
        for (final h in r.habits) {
          expect(h.trim(), isNotEmpty, reason: '${r.name} habit');
        }
        for (final a in r.artifacts) {
          expect(a.trim(), isNotEmpty, reason: '${r.name} artifact');
        }
      }
    });

    test('article picks a/an by the leading vowel', () {
      RoleCard at(String name) => roleCatalog.firstWhere((r) => r.name == name);
      expect(at('Ant').article, 'an');
      expect(at('Owl').article, 'an');
      expect(at('Octopus').article, 'an');
      expect(at('Bee').article, 'a');
      expect(at('Giraffe').article, 'a');
    });
  });
}
