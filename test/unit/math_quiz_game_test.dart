// Math Game on the unified framework — pure reducer + the single-button
// Reveal→Next→Play-again flow + question (de)serialization.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/math_game.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/math_quiz_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const game = MathQuizGame();

  Map<String, dynamic> stateAt({int i = 0, bool r = false, bool d = false}) => {
        'i': i,
        'r': r,
        'd': d,
        'n': 2,
        'qs': [
          {'m': 'choose', 'p': '2 + 3', 'a': 5, 'c': [5, 4, 6, 7]},
          {'m': 'trueFalse', 'p': '2 + 2 = 5', 'st': false},
        ],
      };

  test('reveal shows the answer', () {
    expect(game.reduce(stateAt(), GameIntent.reveal, const {})['r'], isTrue);
  });

  test('next advances + re-hides; finishes at the end', () {
    final mid = game.reduce(stateAt(r: true), GameIntent.next, const {});
    expect(mid['i'], 1);
    expect(mid['r'], isFalse);
    final end = game.reduce(stateAt(i: 1, r: true), GameIntent.next, const {});
    expect(end['d'], isTrue);
  });

  test('reset replays from the start', () {
    final r = game.reduce(stateAt(i: 1, r: true, d: true), GameIntent.reset, const {});
    expect(r['i'], 0);
    expect(r['r'], isFalse);
    expect(r['d'], isFalse);
  });

  test('decode reconstructs typed questions', () {
    final s = game.decode(stateAt());
    expect(s.total, 2);
    expect(s.question!.mechanic, MathMechanic.choose);
    expect(s.question!.prompt, '2 + 3');
    expect(s.question!.answer, 5);
    final tf = game.decode(stateAt(i: 1)).question!;
    expect(tf.mechanic, MathMechanic.trueFalse);
    expect(tf.statementTrue, isFalse);
  });

  test('single-button flow: reveal → next → reset', () {
    expect(game.activeIntents(game.decode(stateAt())), {GameIntent.reveal});
    expect(game.activeIntents(game.decode(stateAt(r: true))), {GameIntent.next});
    expect(game.activeIntents(game.decode(stateAt(d: true))), {GameIntent.reset});
  });

  test('initialState generates a serialized round', () {
    final s = game.initialState(LocalContentBank.seeded());
    final qs = s['qs'] as List;
    expect(qs, isNotEmpty);
    expect(s['n'], qs.length);
    // Round-trips back into typed questions.
    expect(game.decode(s).questions.length, qs.length);
  });
}
