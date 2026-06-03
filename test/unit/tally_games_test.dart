// The host-paced tally games (Rhyme Time, Letter Words) on the unified
// framework. Pure reducers + content + decode. The shared control bar +
// live transport aren't unit-tested (widget/on-device); the rules are.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/letter_words_game.dart';
import 'package:differentworld/features/games/games/rhyme_time_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RhymeTimeGame', () {
    const game = RhymeTimeGame();
    Map<String, dynamic> stateAt({int i = 0, int f = 0, int n = 3}) => {
          'i': i,
          'f': f,
          'n': n,
          'words': [for (var k = 0; k < n; k++) 'word$k'],
        };

    test('tally counts a rhyme', () {
      final r = game.reduce(stateAt(f: 2), GameIntent.tally, const {});
      expect(r['f'], 3);
      expect(r['i'], 0); // same word
    });

    test('next advances the word and resets the count', () {
      final r = game.reduce(stateAt(f: 5), GameIntent.next, const {});
      expect(r['i'], 1);
      expect(r['f'], 0);
    });

    test('next wraps at the end', () {
      final r = game.reduce(stateAt(i: 2), GameIntent.next, const {});
      expect(r['i'], 0);
    });

    test('reset zeroes index + count', () {
      final r = game.reduce(stateAt(i: 2, f: 4), GameIntent.reset, const {});
      expect(r['i'], 0);
      expect(r['f'], 0);
    });

    test('decode exposes the current word', () {
      expect(game.decode(stateAt(i: 1)).word, 'word1');
    });

    test('initialState pulls rhyme words from the bank', () {
      final s = game.initialState(LocalContentBank.seeded());
      expect(s['n'] as int, greaterThan(0));
      expect((s['words'] as List).length, s['n']);
    });

    test('always offers tally / next / reset', () {
      expect(
        game.activeIntents(game.decode(stateAt())),
        {GameIntent.tally, GameIntent.next, GameIntent.reset},
      );
    });
  });

  group('LetterWordsGame', () {
    const game = LetterWordsGame();
    Map<String, dynamic> stateAt({int i = 0, int f = 0}) => {
          'i': i,
          'f': f,
          'n': 3,
          'rounds': [
            ['A', 'animals'],
            ['B', 'foods'],
            ['C', 'colors'],
          ],
        };

    test('tally counts a word', () {
      expect(game.reduce(stateAt(f: 1), GameIntent.tally, const {})['f'], 2);
    });

    test('next advances the round and resets the count', () {
      final r = game.reduce(stateAt(f: 4), GameIntent.next, const {});
      expect(r['i'], 1);
      expect(r['f'], 0);
    });

    test('decode exposes the current letter + category', () {
      final s = game.decode(stateAt(i: 1));
      expect(s.letter, 'B');
      expect(s.category, 'foods');
    });

    test('initialState builds [letter, category] rounds, never empty', () {
      final s = game.initialState(LocalContentBank.seeded());
      final rounds = s['rounds'] as List;
      expect(rounds, isNotEmpty);
      for (final r in rounds) {
        final pair = r as List;
        expect((pair[0] as String).trim(), isNotEmpty); // letter
        expect((pair[1] as String).trim(), isNotEmpty); // category
      }
    });
  });
}
