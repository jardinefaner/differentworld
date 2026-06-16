// Pins the Odd One Out reducer (docs/CARD_GAMES.md) — the i/n/d/r state machine
// over rounds of four cards (three from a category + one stranger).

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/odd_one_out_game.dart';
import 'package:flutter_test/flutter_test.dart';

const _game = OddOneOutGame();

Map<String, dynamic> _seed() => {
      'rounds': [
        {
          'cards': [
            {'image': 'a.png', 'label': 'apple'},
            {'image': 'b.png', 'label': 'banana'},
            {'image': 'c.png', 'label': 'cherry'},
            {'image': 'ball.png', 'label': 'ball'},
          ],
          'answer': 3,
        },
        {
          'cards': [
            {'image': 'dog.png', 'label': 'dog'},
            {'image': 'cat.png', 'label': 'cat'},
            {'image': 'cow.png', 'label': 'cow'},
            {'image': 'car.png', 'label': 'car'},
          ],
          'answer': 3,
        },
      ],
      'i': 0,
      'r': false,
      'd': false,
    };

Map<String, dynamic> _do(Map<String, dynamic> s, GameIntent i) =>
    _game.reduce(s, i, const {});

void main() {
  group('OddOneOutGame reducer', () {
    test('current round exposes the odd card', () {
      final st = _game.decode(_seed());
      expect(st.current!.answer, 3);
      expect(st.current!.odd!.label, 'ball');
      expect(st.current!.cards.length, 4);
    });

    test('reveal flips r; next clears it + advances', () {
      var s = _seed();
      s = _do(s, GameIntent.reveal);
      expect(_game.decode(s).revealed, isTrue);
      s = _do(s, GameIntent.next);
      final st = _game.decode(s);
      expect(st.index, 1);
      expect(st.revealed, isFalse); // reset on advance
      expect(st.current!.odd!.label, 'car');
    });

    test('next past the last round marks done + clamps', () {
      var s = _seed();
      s = _do(s, GameIntent.next); // ->1 (last)
      s = _do(s, GameIntent.next); // past last
      expect(_game.decode(s).done, isTrue);
      expect(_game.decode(s).index, 1);
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

    test('reset returns to the first round, hidden', () {
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
