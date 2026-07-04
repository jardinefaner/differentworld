// RiddlesGame reducer — the reveal-game template (docs/GAMES.md Wave 1b).
// Covers the edges the widget test doesn't (back, done at the end, reset).

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/riddles_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const def = RiddlesGame();

  Map<String, dynamic> st({int i = 0, bool r = false, bool d = false}) => {
    'i': i,
    'r': r,
    'd': d,
    'n': 10,
    'items': const [
      ['What has hands but cannot clap?', 'A clock'],
    ],
  };

  test('reveal toggles', () {
    expect(def.reduce(st(), GameIntent.reveal, const {})['r'], isTrue);
    expect(def.reduce(st(r: true), GameIntent.reveal, const {})['r'], isFalse);
  });

  test('next advances and clears the reveal', () {
    final r = def.reduce(st(i: 2, r: true), GameIntent.next, const {});
    expect(r['i'], 3);
    expect(r['r'], isFalse);
  });

  test('next on the last riddle ends the round', () {
    expect(def.reduce(st(i: 9), GameIntent.next, const {})['d'], isTrue);
  });

  test('back steps back and clears reveal; stops at 0; un-dones from done', () {
    expect(def.reduce(st(i: 3, r: true), GameIntent.back, const {})['i'], 2);
    expect(def.reduce(st(), GameIntent.back, const {})['i'], 0);
    expect(
      def.reduce(st(i: 9, d: true), GameIntent.back, const {})['d'],
      isFalse,
    );
  });

  test('reset returns to the start', () {
    final r = def.reduce(
      st(i: 5, r: true, d: true),
      GameIntent.reset,
      const {},
    );
    expect(r['i'], 0);
    expect(r['r'], isFalse);
    expect(r['d'], isFalse);
  });

  test('activeIntents: reveal+next while playing, back only after slide 0', () {
    expect(def.activeIntents(def.decode(st())), {
      GameIntent.reveal,
      GameIntent.next,
    });
    expect(
      def.activeIntents(def.decode(st(i: 1))).contains(GameIntent.back),
      isTrue,
    );
    expect(def.activeIntents(def.decode(st(i: 9, d: true))), {
      GameIntent.back,
      GameIntent.reset,
    });
  });
}
