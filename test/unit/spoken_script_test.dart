// The karaoke timing logic (the Speak feature): ElevenLabs char-level
// alignment → words with time windows, and the current-word lookup that
// drives the highlight. Pure functions — no audio, no network.

import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wordsFromAlignment', () {
    test('groups characters into words on whitespace', () {
      // "Hi there" — H i _ t h e r e
      final words = wordsFromAlignment(
        characters: ['H', 'i', ' ', 't', 'h', 'e', 'r', 'e'],
        startSeconds: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7],
        endSeconds: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
      );
      expect(words.map((w) => w.text), ['Hi', 'there']);
      expect(words[0].start, Duration.zero);
      expect(words[0].end, const Duration(milliseconds: 200));
      expect(words[1].start, const Duration(milliseconds: 300));
      expect(words[1].end, const Duration(milliseconds: 800));
    });

    test('keeps punctuation attached + ignores leading/trailing space', () {
      final words = wordsFromAlignment(
        characters: [' ', 'G', 'o', '!', ' '],
        startSeconds: [0.0, 0.1, 0.2, 0.3, 0.4],
        endSeconds: [0.1, 0.2, 0.3, 0.4, 0.5],
      );
      expect(words.map((w) => w.text), ['Go!']);
      expect(words.single.start, const Duration(milliseconds: 100));
    });

    test('truncates ragged input to the shortest array', () {
      final words = wordsFromAlignment(
        characters: ['a', 'b', 'c'],
        startSeconds: [0.0, 0.1],
        endSeconds: [0.1, 0.2],
      );
      // Only 2 chars usable → one word "ab".
      expect(words.map((w) => w.text), ['ab']);
    });
  });

  group('currentWordIndex', () {
    final words = [
      const SpokenWord(
        text: 'one',
        start: Duration.zero,
        end: Duration(milliseconds: 500),
      ),
      const SpokenWord(
        text: 'two',
        start: Duration(milliseconds: 500),
        end: Duration(seconds: 1),
      ),
    ];

    test('-1 before the first word (lead-in silence)', () {
      expect(
        currentWordIndex(words, const Duration(milliseconds: -1)),
        -1,
      );
    });

    test('tracks the spoken word as the position advances', () {
      expect(currentWordIndex(words, Duration.zero), 0);
      expect(currentWordIndex(words, const Duration(milliseconds: 300)), 0);
      expect(currentWordIndex(words, const Duration(milliseconds: 500)), 1);
      expect(currentWordIndex(words, const Duration(seconds: 2)), 1);
    });

    test('empty script → -1', () {
      expect(currentWordIndex(const [], const Duration(seconds: 1)), -1);
    });
  });
}
