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

  group('roleDecks', () {
    test('ships at least the animals + people decks', () {
      expect(roleDecks.length, greaterThanOrEqualTo(2));
      final ids = roleDecks.map((d) => d.id).toSet();
      expect(ids, containsAll(<String>['animals', 'people']));
    });

    test('roleCatalog stays the animals deck (back-compat alias)', () {
      final animals = roleDecks.firstWhere((d) => d.id == 'animals');
      expect(roleCatalog, same(animals.cards));
    });

    test('every deck card has 3 habits + 3 artifacts + a trait + an icon', () {
      for (final deck in roleDecks) {
        expect(deck.cards, isNotEmpty, reason: '${deck.name} has cards');
        expect(deck.emoji.trim(), isNotEmpty, reason: '${deck.name} icon');
        expect(deck.tagline.trim(), isNotEmpty, reason: '${deck.name} tagline');
        final fps = deck.cards.map((c) => c.fingerprint).toSet();
        expect(
          fps,
          hasLength(deck.cards.length),
          reason: '${deck.name} fingerprints unique within the deck',
        );
        for (final c in deck.cards) {
          expect(c.habits, hasLength(3), reason: '${c.name} habits');
          expect(c.artifacts, hasLength(3), reason: '${c.name} artifacts');
          expect(c.emoji.trim(), isNotEmpty, reason: '${c.name} emoji');
          expect(c.builds.trim(), isNotEmpty, reason: '${c.name} builds');
        }
      }
    });

    test('people deck has an Astronaut that builds courage', () {
      final people = roleDecks.firstWhere((d) => d.id == 'people');
      final astro = people.cards.firstWhere((c) => c.name == 'Astronaut');
      expect(astro.builds, 'courage');
      expect(astro.habits, hasLength(3));
    });
  });
}
