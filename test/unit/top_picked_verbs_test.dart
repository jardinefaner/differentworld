import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The activity matcher opens pre-filtered to the cohort's most-picked verbs
/// (THE_DAY.md's 15-second Verb-Hour touch). `rankVerbsByPickCount` is the
/// pure ranker behind that default.
void main() {
  group('rankVerbsByPickCount', () {
    test('ranks by how many kids picked each verb, most first', () {
      final ranked = rankVerbsByPickCount([
        ['carry', 'listen', 'build'],
        ['carry', 'listen', 'play'],
        ['carry', 'build', 'flow'],
      ]);
      // carry x3, build x2, listen x2, then the singles.
      expect(ranked.first, 'carry');
      expect(ranked.take(3).toSet(), {'carry', 'build', 'listen'});
    });

    test('caps the list (default 4)', () {
      final ranked = rankVerbsByPickCount([
        ['a', 'b', 'c'],
        ['d', 'e', 'f'],
        ['g', 'h', 'i'],
      ]);
      expect(ranked.length, 4);
    });

    test('respects a custom cap', () {
      final ranked = rankVerbsByPickCount([
        ['a', 'b', 'c'],
      ], cap: 2);
      expect(ranked.length, 2);
    });

    test('ties break alphabetically (stable)', () {
      // build + carry both picked once → alphabetical: build before carry.
      final ranked = rankVerbsByPickCount([
        ['carry', 'build'],
      ]);
      expect(ranked, ['build', 'carry']);
    });

    test('no picks → empty (matcher falls back to all activities)', () {
      expect(rankVerbsByPickCount(const []), isEmpty);
      expect(rankVerbsByPickCount([<String>[]]), isEmpty);
    });
  });
}
