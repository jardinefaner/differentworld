// Pins the Name It reducer (docs/CARD_GAMES.md) — the i/n/d/r state machine
// over a deck of picture cards.

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/name_it_game.dart';
import 'package:flutter_test/flutter_test.dart';

const _game = NameItGame();

Map<String, dynamic> _seed() => {
      'cards': const [
        {'image': 'a.png', 'label': 'apple'},
        {'image': 'b.png', 'label': 'banana'},
        {'image': 'c.png', 'label': 'cat'},
      ],
      'i': 0,
      'r': false,
      'd': false,
    };

Map<String, dynamic> _do(Map<String, dynamic> s, GameIntent i) =>
    _game.reduce(s, i, const {});

void main() {
  group('NameItGame reducer', () {
    test('reveal shows the word; next clears it + advances', () {
      var s = _seed();
      s = _do(s, GameIntent.reveal);
      expect(_game.decode(s).revealed, isTrue);
      s = _do(s, GameIntent.next);
      final st = _game.decode(s);
      expect(st.index, 1);
      expect(st.revealed, isFalse); // reset on advance
      expect(st.current!.label, 'banana');
    });

    test('next past the last card marks done', () {
      var s = _seed();
      s = _do(s, GameIntent.next); // ->1
      s = _do(s, GameIntent.next); // ->2 (last)
      expect(_game.decode(s).index, 2);
      s = _do(s, GameIntent.next); // past last
      expect(_game.decode(s).done, isTrue);
      expect(_game.decode(s).index, 2); // clamped
    });

    test('back steps and un-dones', () {
      var s = _seed();
      s = _do(s, GameIntent.next);
      s = _do(s, GameIntent.reveal);
      s = _do(s, GameIntent.back);
      final st = _game.decode(s);
      expect(st.index, 0);
      expect(st.revealed, isFalse);
      expect(st.done, isFalse);
    });

    test('reset returns to the first card, hidden', () {
      var s = _seed();
      s = _do(s, GameIntent.next);
      s = _do(s, GameIntent.reveal);
      s = _do(s, GameIntent.reset);
      final st = _game.decode(s);
      expect(st.index, 0);
      expect(st.revealed, isFalse);
      expect(st.done, isFalse);
    });

    test('activeIntents: no Back at start, no Reveal once revealed', () {
      final start = _game.decode(_seed());
      expect(_game.activeIntents(start), isNot(contains(GameIntent.back)));
      expect(_game.activeIntents(start), contains(GameIntent.reveal));
      final revealed = _game.decode(_do(_seed(), GameIntent.reveal));
      expect(_game.activeIntents(revealed), isNot(contains(GameIntent.reveal)));
    });
  });
}
