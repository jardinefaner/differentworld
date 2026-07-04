// Pins the What's Missing reducer (docs/CARD_GAMES.md) — the three-beat
// (study → quiz → revealed) state machine over rounds of a picture set.

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/whats_missing_game.dart';
import 'package:flutter_test/flutter_test.dart';

const _game = WhatsMissingGame();

Map<String, dynamic> _seed() => {
  'rounds': [
    {
      'cards': [
        {'image': 'a.png', 'label': 'apple'},
        {'image': 'b.png', 'label': 'banana'},
        {'image': 'c.png', 'label': 'cat'},
      ],
      'missing': 1,
    },
    {
      'cards': [
        {'image': 'd.png', 'label': 'dog'},
        {'image': 'e.png', 'label': 'egg'},
      ],
      'missing': 0,
    },
  ],
  'i': 0,
  'phase': 0,
  'd': false,
};

Map<String, dynamic> _do(Map<String, dynamic> s, GameIntent i) =>
    _game.reduce(s, i, const {});

void main() {
  group('WhatsMissingGame reducer', () {
    test('current round exposes the card that hides', () {
      final st = _game.decode(_seed());
      expect(st.current!.missingIndex, 1);
      expect(st.current!.missing!.label, 'banana');
      expect(st.current!.cards.length, 3);
    });

    test('reveal walks study -> quiz -> revealed and clamps', () {
      var s = _seed();
      expect(_game.decode(s).phase, MissingPhase.study);
      s = _do(s, GameIntent.reveal);
      expect(_game.decode(s).phase, MissingPhase.quiz);
      s = _do(s, GameIntent.reveal);
      expect(_game.decode(s).phase, MissingPhase.revealed);
      s = _do(s, GameIntent.reveal); // clamp at revealed
      expect(_game.decode(s).phase, MissingPhase.revealed);
    });

    test('next advances the round and resets to study', () {
      var s = _seed();
      s = _do(s, GameIntent.reveal); // quiz
      s = _do(s, GameIntent.next); // round 2
      final st = _game.decode(s);
      expect(st.index, 1);
      expect(st.phase, MissingPhase.study);
      expect(st.current!.missing!.label, 'dog');
    });

    test('next on the last round marks done', () {
      var s = _seed();
      s = _do(s, GameIntent.next); // ->1 (last)
      s = _do(s, GameIntent.next); // past last
      expect(_game.decode(s).done, isTrue);
    });

    test('back within the first round steps the beat down', () {
      var s = _seed();
      s = _do(s, GameIntent.reveal); // quiz
      s = _do(s, GameIntent.back); // back to study (i stays 0)
      final st = _game.decode(s);
      expect(st.index, 0);
      expect(st.phase, MissingPhase.study);
    });

    test('back from a later round goes to the previous round at study', () {
      var s = _seed();
      s = _do(s, GameIntent.next); // round 2 (i=1)
      s = _do(s, GameIntent.reveal); // quiz
      s = _do(s, GameIntent.back); // -> round 1, study
      final st = _game.decode(s);
      expect(st.index, 0);
      expect(st.phase, MissingPhase.study);
    });

    test('reset returns to the first round at study', () {
      var s = _seed();
      s = _do(s, GameIntent.next);
      s = _do(s, GameIntent.reveal);
      s = _do(s, GameIntent.reset);
      final st = _game.decode(s);
      expect(st.index, 0);
      expect(st.phase, MissingPhase.study);
      expect(st.done, isFalse);
    });
  });
}
