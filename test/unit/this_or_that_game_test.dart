// ThisOrThatGame — the reducer + state that now drive BOTH the single-device
// (/activity) and live (/live) paths (docs/GAMES.md Wave 0b/0c). These cases
// were ported verbatim from the old LiveState.reduce test when This-or-That's
// logic moved to its single source of truth — so the live path's correctness
// (which can't be unit-tested over the Realtime transport) rides on this.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/this_or_that_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const def = ThisOrThatGame();

  // A wire-state with the conventional keys + a constant pairs payload, so we
  // can assert the reducer passes content through untouched.
  Map<String, dynamic> st({int i = 0, bool r = false, bool d = false}) => {
    'i': i,
    'r': r,
    'd': d,
    'n': 8,
    'pairs': const [
      ['Pizza', 'Tacos'],
      ['Summer', 'Winter'],
    ],
  };

  group('ThisOrThatGame.reduce', () {
    test('next advances and clears the reveal', () {
      final r = def.reduce(st(i: 2, r: true), GameIntent.next, const {});
      expect(r['i'], 3);
      expect(r['r'], isFalse);
      expect(r['d'], isFalse);
    });

    test('next on the last slide ends the round', () {
      expect(def.reduce(st(i: 7), GameIntent.next, const {})['d'], isTrue);
    });

    test('next when already done is a no-op', () {
      final r = def.reduce(st(i: 7, d: true), GameIntent.next, const {});
      expect(r['d'], isTrue);
      expect(r['i'], 7);
    });

    test('back decrements and clears reveal; stops at 0', () {
      expect(
        def.reduce(st(i: 3, r: true), GameIntent.back, const {})['i'],
        2,
      );
      expect(def.reduce(st(), GameIntent.back, const {})['i'], 0);
    });

    test('back from done un-dones (returns to the last slide)', () {
      final r = def.reduce(st(i: 7, d: true), GameIntent.back, const {});
      expect(r['d'], isFalse);
    });

    test('reveal toggles', () {
      expect(def.reduce(st(), GameIntent.reveal, const {})['r'], isTrue);
      expect(
        def.reduce(st(r: true), GameIntent.reveal, const {})['r'],
        isFalse,
      );
    });

    test('reset resets everything', () {
      final r = def.reduce(st(i: 5, r: true, d: true), GameIntent.reset, const {});
      expect(r['i'], 0);
      expect(r['r'], isFalse);
      expect(r['d'], isFalse);
    });

    test('pick / tally / capture / submit are no-ops', () {
      for (final intent in [
        GameIntent.pick,
        GameIntent.tally,
        GameIntent.capture,
        GameIntent.submit,
      ]) {
        final r = def.reduce(st(i: 4, r: true), intent, const {});
        expect(r['i'], 4, reason: '$intent left index alone');
        expect(r['r'], isTrue, reason: '$intent left reveal alone');
      }
    });

    test('the reducer preserves the content payload (key for the live path)', () {
      final r = def.reduce(st(), GameIntent.next, const {});
      expect(r['pairs'], st()['pairs'], reason: 'pairs ride the broadcast');
      expect(r['n'], 8);
    });

    test('the reducer is pure — it does not mutate the input', () {
      final input = st(i: 1);
      def.reduce(input, GameIntent.next, const {});
      expect(input['i'], 1, reason: 'input untouched; a new map is returned');
    });
  });

  group('ThisOrThatState decode', () {
    test('decodes the conventional keys + pairs', () {
      final s = def.decode(st(i: 1, r: true));
      expect(s.index, 1);
      expect(s.revealed, isTrue);
      expect(s.done, isFalse);
      expect(s.current, ('Summer', 'Winter'));
    });

    test('tolerates missing / wrong-typed keys', () {
      final empty = def.decode(const {});
      expect(empty.index, 0);
      expect(empty.revealed, isFalse);
      expect(empty.done, isFalse);
      expect(empty.current, ('', ''), reason: 'no pairs → safe blank');
    });
  });

  group('ThisOrThatGame.initialState', () {
    test('resolves 8 pairs from content into a self-describing state', () {
      final state = def.initialState(LocalContentBank(curatedSeeds));
      expect(state['n'], 8);
      expect((state['pairs'] as List).length, 8);
      expect(state['i'], 0);
      expect(state['d'], false);
    });
  });
}
