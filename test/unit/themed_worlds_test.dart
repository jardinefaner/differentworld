import 'package:differentworld/features/action_words/themed_worlds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('world facets', () {
    test('are the ten world-building dimensions, in order', () {
      final ids = kWorldFacets.map((f) => f.id).toList();
      expect(ids, [
        'people',
        'culture',
        'map',
        'tools',
        'language',
        'food',
        'music',
        'rules',
        'problems',
        'dreams',
      ]);
      for (final f in kWorldFacets) {
        expect(f.emoji, isNotEmpty);
        expect(f.name, isNotEmpty);
      }
    });
  });
}
