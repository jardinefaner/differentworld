import 'package:differentworld/features/action_words/themed_worlds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('themed worlds catalog', () {
    test('every world has unique id, name, room, emoji, and senses', () {
      final ids = <String>{};
      for (final w in kThemedWorlds) {
        expect(w.id, isNotEmpty);
        expect(ids.add(w.id), isTrue, reason: 'duplicate id ${w.id}');
        expect(w.name, isNotEmpty);
        expect(w.room, isNotEmpty);
        expect(w.emoji, isNotEmpty);
        expect(w.blurb, isNotEmpty);
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

    test('starter set covers the brief sequence', () {
      final ids = kThemedWorlds.map((w) => w.id).toSet();
      expect(
        ids,
        containsAll(<String>[
          'all_about_me',
          'wildlife',
          'travel',
          'water_world',
          'icons',
          'space',
        ]),
      );
    });
  });
}
