import 'package:differentworld/features/action_words/themed_worlds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('themed worlds catalog', () {
    test('every world has unique id, name, tagline, emoji, and senses', () {
      final ids = <String>{};
      for (final w in kThemedWorlds) {
        expect(w.id, isNotEmpty);
        expect(ids.add(w.id), isTrue, reason: 'duplicate id ${w.id}');
        expect(w.name, isNotEmpty);
        expect(w.tagline, isNotEmpty);
        expect(w.emoji, isNotEmpty);
        expect(w.senses, isNotEmpty, reason: '${w.id} has no sense beats');
        for (final beat in w.senses) {
          expect(beat.prompt, isNotEmpty);
        }
      }
    });

    test('themedWorldById round-trips and is null-safe', () {
      expect(themedWorldById(null), isNull);
      expect(themedWorldById('nope'), isNull);
      for (final w in kThemedWorlds) {
        expect(themedWorldById(w.id), same(w));
      }
    });

    test('catalog is the Different World anthology', () {
      final ids = kThemedWorlds.map((w) => w.id).toSet();
      expect(
        ids,
        containsAll(<String>[
          'books',
          'movies',
          'songs',
          'dreams',
          'space',
          'time',
        ]),
      );
    });

    test('world facets are the five world-building dimensions', () {
      final ids = kWorldFacets.map((f) => f.id).toList();
      expect(ids, ['people', 'culture', 'map', 'tools', 'dreams']);
      for (final f in kWorldFacets) {
        expect(f.emoji, isNotEmpty);
        expect(f.name, isNotEmpty);
        expect(f.prompt, isNotEmpty);
      }
    });
  });
}
