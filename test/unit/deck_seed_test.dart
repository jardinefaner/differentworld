// The deck-seeded path IS the app path. Every unit test seeded the classics
// through `initialState` and passed, while every real device seeded them
// through the deck wrapper (classic_boards_screen.dart) — which built a bare
// board of images: no labels, no tally. So the app shipped a Bingo with no
// caller and a Guess Who whose secret was always square zero, behind a green
// suite. These pin the seed path to what the game path produces.

import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/classic_boards_screen.dart';
import 'package:differentworld/features/games/games/guess_who_game.dart';
import 'package:differentworld/features/games/games/spot_difference_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<PictureCard> deck(int n) => [
    for (var i = 0; i < n; i++)
      PictureCard(
        id: 'card$i',
        label: 'thing $i',
        image: 'assets/decks/card$i.png',
        category: i.isEven ? 'food' : 'toys',
        deck: 'test',
      ),
  ];

  group('bingo from the deck', () {
    test('the board calls a square, by name', () {
      const g = BingoGame();
      final b = g.decode(bingoSeed(deck(40)));
      expect(b.cells, hasLength(16));
      expect(BingoGame.calledOf(b), inInclusiveRange(0, 15), reason: 'a call');
      expect(BingoGame.callOf(b), isNotNull, reason: 'and it has a name');
      expect(g.asShape(b)!.title, BingoGame.callOf(b));
    });

    test('marking the called square draws the next', () {
      const g = BingoGame();
      var wire = bingoSeed(deck(40));
      final first = BingoGame.calledOf(g.decode(wire));
      wire = g.reduce(wire, GameIntent.pick, {'cell': first});
      expect(BingoGame.calledOf(g.decode(wire)), isNot(first));
    });

    test('a short deck still fills the card', () {
      final b = const BingoGame().decode(bingoSeed(deck(5)));
      expect(b.cells, hasLength(16));
      expect(b.cells.every((c) => c.face != null), isTrue);
    });
  });

  group('guess who from the deck', () {
    test('is thinking of somebody, and not always square zero', () {
      final secrets = <int>{};
      for (var i = 0; i < 40; i++) {
        secrets.add(
          GuessWhoGame.secretOf(
            const GuessWhoGame().decode(guessWhoSeed(deck(30))),
          ),
        );
      }
      expect(secrets.length, greaterThan(1), reason: 'a random secret');
      expect(secrets.every((s) => s >= 0 && s < 12), isTrue);
    });
  });

  group('spot the difference from the deck', () {
    test('deals a full two-sided board — it was empty on a fresh install', () {
      const g = SpotDifferenceGame();
      final b = g.decode(spotDifferenceSeed(deck(40)));
      expect(b.cells, hasLength(g.cols * g.rows));
      final gap = [for (var r = 0; r < g.rows; r++) r * g.cols + 3];
      for (var i = 0; i < b.cells.length; i++) {
        if (gap.contains(i)) {
          expect(b.cells[i].state, CellState.done, reason: 'the gap column');
        } else {
          expect(b.cells[i].face, isNotNull, reason: 'square $i has art');
        }
      }
      expect(
        b.cells.where((c) => c.label == 'x'),
        hasLength(2),
        reason: 'the changed square is marked on both sides',
      );
    });

    test('finding it ends the round', () {
      const g = SpotDifferenceGame();
      var wire = spotDifferenceSeed(deck(40));
      final b = g.decode(wire);
      // The RIGHT-hand copy is the one that differs; either marked cell
      // counts as the find.
      final at = b.cells.indexWhere((c) => c.label == 'x');
      wire = g.reduce(wire, GameIntent.pick, {'cell': at});
      expect(g.decode(wire).done, isTrue);
      expect(g.outcomeLine(g.decode(wire)), isNotNull);
    });

    test('an empty deck deals an empty board, not a crash', () {
      final b = const SpotDifferenceGame().decode(spotDifferenceSeed(const []));
      expect(b.cells, isEmpty);
    });
  });
}
