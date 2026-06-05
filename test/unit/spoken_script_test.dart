// The karaoke timing logic (the Speak feature): ElevenLabs char-level
// alignment → words with time windows, and the current-word lookup that
// drives the highlight. Pure functions — no audio, no network.

import 'dart:convert';

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

  group('linesFromWords', () {
    SpokenWord w(String t, int startMs, int endMs) => SpokenWord(
      text: t,
      start: Duration(milliseconds: startMs),
      end: Duration(milliseconds: endMs),
    );

    test('breaks after sentence-ending punctuation', () {
      final lines = linesFromWords([
        w('Hello', 0, 100),
        w('world.', 100, 200),
        w('Goodbye', 200, 300),
        w('now.', 300, 400),
      ]);
      expect(lines.map((l) => l.text), ['Hello world.', 'Goodbye now.']);
      expect(lines[0].start, Duration.zero);
      expect(lines[0].end, const Duration(milliseconds: 200));
      expect(lines[1].start, const Duration(milliseconds: 200));
    });

    test('breaks before a word that would exceed maxChars', () {
      final lines = linesFromWords(
        [
          w('aaaa', 0, 100),
          w('bbbb', 100, 200),
          w('cccc', 200, 300),
          w('dddd', 300, 400),
        ],
        maxChars: 12,
      );
      expect(lines.map((l) => l.text), ['aaaa bbbb', 'cccc dddd']);
    });

    test('does NOT orphan a short clause (clause break needs minChars)', () {
      // "Yes," is under minChars, so it stays with the rest of the sentence.
      final lines = linesFromWords([
        w('Yes,', 0, 100),
        w('we', 100, 200),
        w('should', 200, 300),
        w('go.', 300, 400),
      ]);
      expect(lines.map((l) => l.text), ['Yes, we should go.']);
    });

    test('breaks after a clause once the line has heft', () {
      final lines = linesFromWords(
        [
          w('First', 0, 100),
          w('thing,', 100, 200),
          w('second', 200, 300),
          w('thing.', 300, 400),
        ],
        minChars: 8,
      );
      expect(lines.map((l) => l.text), ['First thing,', 'second thing.']);
    });

    test('a single over-long word still gets its own line (never dropped)', () {
      final lines = linesFromWords(
        [
          w('Supercalifragilistic', 0, 100),
          w('ok', 100, 200),
        ],
        maxChars: 8,
      );
      expect(lines.map((l) => l.text), ['Supercalifragilistic', 'ok']);
    });

    test('empty input → no lines', () {
      expect(linesFromWords(const []), isEmpty);
    });
  });

  group('lineIndexAt', () {
    final lines = [
      const SpokenLine(
        words: [
          SpokenWord(
            text: 'first',
            start: Duration.zero,
            end: Duration(milliseconds: 500),
          ),
        ],
      ),
      const SpokenLine(
        words: [
          SpokenWord(
            text: 'second',
            start: Duration(milliseconds: 500),
            end: Duration(seconds: 1),
          ),
        ],
      ),
    ];

    test('-1 before the first line', () {
      expect(lineIndexAt(lines, const Duration(milliseconds: -1)), -1);
    });

    test('tracks the line + persists past its end through the pause', () {
      expect(lineIndexAt(lines, Duration.zero), 0);
      expect(lineIndexAt(lines, const Duration(milliseconds: 300)), 0);
      expect(lineIndexAt(lines, const Duration(milliseconds: 500)), 1);
      expect(lineIndexAt(lines, const Duration(seconds: 5)), 1);
    });

    test('empty → -1', () {
      expect(lineIndexAt(const [], const Duration(seconds: 1)), -1);
    });
  });

  group('wordEmphasis', () {
    test('ALL-CAPS words score high', () {
      expect(wordEmphasis('STOP'), greaterThan(wordEmphasis('stop')));
      expect(wordEmphasis('STOP'), greaterThan(0.5));
    });

    test('longer words score higher than short ones', () {
      expect(
        wordEmphasis('extraordinary'),
        greaterThan(wordEmphasis('cat')),
      );
    });

    test('an exclamation adds emphasis', () {
      expect(wordEmphasis('go!'), greaterThan(wordEmphasis('go')));
    });

    test('lone letters / pure digits / empties do not shout', () {
      expect(wordEmphasis('I'), 0);
      expect(wordEmphasis('2024'), 0);
      expect(wordEmphasis('—'), 0);
    });

    test('score stays within 0..1', () {
      expect(wordEmphasis('UNBELIEVABLE!'), inInclusiveRange(0, 1));
    });
  });

  group('endsSentence', () {
    test('true for . ! ?', () {
      expect(endsSentence('end.'), isTrue);
      expect(endsSentence('wow!'), isTrue);
      expect(endsSentence('really?'), isTrue);
    });

    test('false for mid-sentence words / clauses', () {
      expect(endsSentence('and'), isFalse);
      expect(endsSentence('then,'), isFalse);
      expect(endsSentence(''), isFalse);
    });
  });

  group('pagesFromInput', () {
    SpokenWord w(String t) => SpokenWord(
      text: t,
      start: Duration.zero,
      end: const Duration(milliseconds: 100),
    );

    test('every input line becomes a page (by word count)', () {
      final pages = pagesFromInput('one two\nthree\nfour five six', [
        w('one'),
        w('two'),
        w('three'),
        w('four'),
        w('five'),
        w('six'),
      ]);
      expect(pages.map((p) => p.text), ['one two', 'three', 'four five six']);
    });

    test('no line breaks → a single page', () {
      final pages = pagesFromInput('just one line here', [
        w('just'),
        w('one'),
        w('line'),
        w('here'),
      ]);
      expect(pages.length, 1);
      expect(pages.single.words.length, 4);
    });

    test('blank lines are ignored', () {
      final pages = pagesFromInput('a\n\n\nb', [w('a'), w('b')]);
      expect(pages.map((p) => p.text), ['a', 'b']);
    });

    test('extra alignment words attach to the last page', () {
      // Input counts 2 words but alignment has 3 → the 3rd joins page 2.
      final pages = pagesFromInput('a\nb', [w('a'), w('b'), w('c')]);
      expect(pages.map((p) => p.text), ['a', 'b c']);
    });

    test('empty words → no pages', () {
      expect(pagesFromInput('a\nb', const []), isEmpty);
    });
  });

  group('SpokenScript JSON', () {
    test('survives a full jsonEncode/decode round-trip (history)', () {
      const script = SpokenScript(
        audioUrl: 'https://example.test/voice/abc.mp3',
        words: [
          SpokenWord(
            text: 'Hello',
            start: Duration.zero,
            end: Duration(milliseconds: 300),
          ),
          SpokenWord(
            text: 'world.',
            start: Duration(milliseconds: 300),
            end: Duration(milliseconds: 800),
          ),
        ],
      );
      final restored = SpokenScript.fromJson(
        jsonDecode(jsonEncode(script.toJson())) as Map<String, dynamic>,
      );
      expect(restored.audioUrl, script.audioUrl);
      expect(restored.words, script.words); // SpokenWord has value equality
    });
  });
}
