// Pins the Memory / Match reducer (docs/CARD_GAMES.md) — the pick-two-to-flip
// concentration machine: a match locks both face-up; a miss leaves both showing
// and the NEXT pick clears them (host-paced, no timer).

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/memory_match_game.dart';
import 'package:flutter_test/flutter_test.dart';

const _game = MemoryMatchGame();

// A 4-card board = two pairs: 0&2 = apple, 1&3 = ball.
Map<String, dynamic> _seed() => {
  'cards': [
    {'image': 'a.png', 'label': 'apple', 'pair': 'apple'}, // 0
    {'image': 'b.png', 'label': 'ball', 'pair': 'ball'}, // 1
    {'image': 'a.png', 'label': 'apple', 'pair': 'apple'}, // 2
    {'image': 'b.png', 'label': 'ball', 'pair': 'ball'}, // 3
  ],
  'flipped': const <int>[],
  'matched': const <int>[],
  'd': false,
};

Map<String, dynamic> _pick(Map<String, dynamic> s, int cell) =>
    _game.reduce(s, GameIntent.pick, {'cell': cell});

void main() {
  group('MemoryMatchGame reducer', () {
    test('pick one flips it face-up', () {
      final s = _pick(_seed(), 0);
      final st = _game.decode(s);
      expect(st.flipped, [0]);
      expect(st.statusOf(0), MemoryCellStatus.up);
      expect(st.pairsTotal, 2);
    });

    test('a matching second pick locks both + clears flipped', () {
      var s = _pick(_seed(), 0);
      s = _pick(s, 2); // same pair (apple)
      final st = _game.decode(s);
      expect(st.matched, {0, 2});
      expect(st.flipped, isEmpty);
      expect(st.statusOf(0), MemoryCellStatus.matched);
      expect(st.pairsFound, 1);
      expect(st.done, isFalse);
    });

    test('a miss leaves both showing; the next pick clears them', () {
      var s = _pick(_seed(), 0);
      s = _pick(s, 1); // different pair (apple vs ball)
      expect(_game.decode(s).flipped, [0, 1]);
      s = _pick(s, 3); // clears 0+1, flips 3
      final st = _game.decode(s);
      expect(st.flipped, [3]);
      expect(st.statusOf(0), MemoryCellStatus.down);
      expect(st.statusOf(1), MemoryCellStatus.down);
      expect(st.statusOf(3), MemoryCellStatus.up);
    });

    test('tapping an already-up or matched cell is a no-op', () {
      var s = _pick(_seed(), 0);
      s = _pick(s, 0); // re-tap the same up card
      expect(_game.decode(s).flipped, [0]);
      s = _pick(s, 2); // match -> 0,2 matched
      s = _pick(s, 0); // tap a matched card
      final st = _game.decode(s);
      expect(st.flipped, isEmpty);
      expect(st.matched, {0, 2});
    });

    test('matching every pair marks the round done', () {
      var s = _seed();
      s = _pick(s, 0);
      s = _pick(s, 2); // apple pair
      s = _pick(s, 1);
      s = _pick(s, 3); // ball pair
      final st = _game.decode(s);
      expect(st.done, isTrue);
      expect(st.pairsFound, 2);
    });

    test('back clears the current flip', () {
      var s = _pick(_seed(), 0);
      s = _game.reduce(s, GameIntent.back, const {});
      expect(_game.decode(s).flipped, isEmpty);
    });

    test('back on an empty flip is a stable no-op', () {
      final s = _game.reduce(_seed(), GameIntent.back, const {});
      expect(_game.decode(s).flipped, isEmpty);
    });

    test(
      'reset reshuffles, clears state, and keeps the same pairs face-down',
      () {
        var s = _seed();
        s = _pick(s, 0);
        s = _pick(s, 2); // a match
        s = _game.reduce(s, GameIntent.reset, const {});
        final st = _game.decode(s);
        expect(st.matched, isEmpty);
        expect(st.flipped, isEmpty);
        expect(st.done, isFalse);
        expect(st.cards.length, 4);
        // The deck is preserved (same multiset of pair keys) — a reshuffle, not a
        // re-deal of different cards.
        final pairs = st.cards.map((c) => c.pair).toList()..sort();
        expect(pairs, ['apple', 'apple', 'ball', 'ball']);
        for (var i = 0; i < 4; i++) {
          expect(st.statusOf(i), MemoryCellStatus.down);
        }
      },
    );

    test('out-of-range pick is ignored', () {
      final s = _pick(_seed(), 99);
      expect(_game.decode(s).flipped, isEmpty);
    });
  });
}
