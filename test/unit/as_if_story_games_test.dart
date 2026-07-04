// As-If + Story Starters on the unified framework — pure reducers + content.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/as_if_game.dart';
import 'package:differentworld/features/games/games/story_starters_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsIfGame', () {
    const game = AsIfGame();
    Map<String, dynamic> stateAt({int li = 0, int ai = 0, int p = 0}) => {
      'li': li,
      'ai': ai,
      'p': p,
      'lines': ['a', 'b', 'c'],
      'asifs': ['x', 'y'],
    };

    test('I did it (tally) counts + advances both cycles', () {
      final r = game.reduce(
        stateAt(li: 1, ai: 1, p: 2),
        GameIntent.tally,
        const {},
      );
      expect(r['p'], 3);
      expect(r['li'], 2);
      expect(r['ai'], 2);
    });

    test('Another one (next) advances without counting', () {
      final r = game.reduce(
        stateAt(li: 1, ai: 1, p: 2),
        GameIntent.next,
        const {},
      );
      expect(r['p'], 2);
      expect(r['li'], 2);
      expect(r['ai'], 2);
    });

    test('reset zeroes everything', () {
      final r = game.reduce(
        stateAt(li: 4, ai: 3, p: 5),
        GameIntent.reset,
        const {},
      );
      expect(r['li'], 0);
      expect(r['ai'], 0);
      expect(r['p'], 0);
    });

    test('decode pairs lines + as-ifs at independent cycle lengths', () {
      final s = game.decode(stateAt(li: 3, ai: 3)); // 3 lines, 2 as-ifs
      expect(s.line, 'a'); // 3 % 3
      expect(s.asIf, 'y'); // 3 % 2
    });

    test('initialState pulls both content banks', () {
      final s = game.initialState(LocalContentBank.seeded());
      expect(s['lines'] as List, isNotEmpty);
      expect(s['asifs'] as List, isNotEmpty);
    });
  });

  group('StoryStartersGame', () {
    const game = StoryStartersGame();
    Map<String, dynamic> stateAt({
      int i = 0,
      int ti = 0,
      String tw = '',
      bool d = false,
      int n = 3,
    }) => {
      'i': i,
      'ti': ti,
      'tw': tw,
      'd': d,
      'n': n,
      'starters': [for (var k = 0; k < n; k++) 'start$k'],
      'twists': ['twist0', 'twist1'],
    };

    test('reveal drops a plot twist and advances the cursor', () {
      final r = game.reduce(stateAt(), GameIntent.reveal, const {});
      expect(r['tw'], 'twist0');
      expect(r['ti'], 1);
      final r2 = game.reduce(r, GameIntent.reveal, const {});
      expect(r2['tw'], 'twist1');
    });

    test('next advances the start and clears the twist', () {
      final r = game.reduce(stateAt(tw: 'twist0'), GameIntent.next, const {});
      expect(r['i'], 1);
      expect(r['tw'], '');
    });

    test('next on the last start finishes', () {
      final r = game.reduce(stateAt(i: 2), GameIntent.next, const {});
      expect(r['d'], isTrue);
    });

    test('reset restarts', () {
      final r = game.reduce(
        stateAt(i: 2, ti: 2, tw: 'twist1', d: true),
        GameIntent.reset,
        const {},
      );
      expect(r['i'], 0);
      expect(r['d'], isFalse);
      expect(r['tw'], '');
    });

    test('activeIntents: in play reveal+next; done reset', () {
      expect(
        game.activeIntents(game.decode(stateAt())),
        {GameIntent.reveal, GameIntent.next},
      );
      expect(
        game.activeIntents(game.decode(stateAt(d: true))),
        {GameIntent.reset},
      );
    });

    test('initialState builds starters + twists', () {
      final s = game.initialState(LocalContentBank.seeded());
      expect(s['starters'] as List, isNotEmpty);
      expect(s['n'], (s['starters'] as List).length);
    });
  });
}
