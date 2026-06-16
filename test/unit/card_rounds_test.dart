// Pins the card-games foundation (docs/CARD_GAMES.md): the manifest parser and
// the pure, seeded round-generators that every card game reads.

import 'package:differentworld/features/games/cards/card_rounds.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:flutter_test/flutter_test.dart';

PictureCard _c(String id, String cat) =>
    PictureCard(id: id, label: id, image: '$id.png', category: cat, deck: 'd');

final _deck = <PictureCard>[
  _c('banana', 'food'), _c('apple', 'food'), _c('cake', 'food'), _c('pear', 'food'),
  _c('violin', 'music'), _c('drum', 'music'),
  _c('ball', 'sport'), _c('bat', 'sport'),
];

void main() {
  group('parseDeckManifest', () {
    test('parses cards, resolves image paths under the asset dir', () {
      const json = '''
      { "deck": "everyday", "cards": [
        { "id": "banana", "label": "banana", "category": "food", "image": "04-banana.png" },
        { "id": "violin", "image": "01-violin.png" }
      ] }''';
      final cards = parseDeckManifest(json, assetDir: 'assets/card_games/everyday');
      expect(cards.length, 2);
      expect(cards[0].image, 'assets/card_games/everyday/04-banana.png');
      expect(cards[0].letter, 'b');
      // missing label falls back to the id (spaces from hyphens); missing
      // category degrades to "thing".
      expect(cards[1].label, 'violin');
      expect(cards[1].category, 'thing');
    });

    test('malformed JSON / bad cards degrade to empty, never throw', () {
      expect(parseDeckManifest('not json', assetDir: 'x'), isEmpty);
      expect(
        parseDeckManifest('{"cards":[{"label":"no id or image"}]}', assetDir: 'x'),
        isEmpty,
      );
    });

    test('round-trips through a ContentItem', () {
      final card = _c('banana', 'food');
      final back = PictureCard.fromContentItem(card.toContentItem());
      expect(back.id, 'banana');
      expect(back.category, 'food');
      expect(back.deck, 'd');
    });
  });

  group('CardRounds (pure + seeded)', () {
    test('hidden picks a card in the deck; same seed → same card', () {
      final a = CardRounds.hidden(_deck, 7);
      final b = CardRounds.hidden(_deck, 7);
      expect(_deck.contains(a), isTrue);
      expect(a.id, b.id); // deterministic
    });

    test('pairs: n pairs, no card reused', () {
      final ps = CardRounds.pairs(_deck, 3, 1);
      expect(ps.length, 3);
      final used = <String>{};
      for (final (x, y) in ps) {
        expect(used.add(x.id), isTrue);
        expect(used.add(y.id), isTrue);
      }
    });

    test('oddOneOut: the answer is a different category from the other three', () {
      final round = CardRounds.oddOneOut(_deck, 2);
      expect(round, isNotNull);
      final opts = round!.options;
      expect(opts.length, 4);
      final oddCat = opts[round.answer].category;
      final rest = [for (var i = 0; i < 4; i++) if (i != round.answer) opts[i]];
      expect(rest.map((c) => c.category).toSet().length, 1); // the 3 share one
      expect(rest.first.category, isNot(oddCat)); // odd differs
    });

    test('oddOneOut returns null when no category has 3', () {
      final flat = [_c('a', 'x'), _c('b', 'y'), _c('c', 'z')];
      expect(CardRounds.oddOneOut(flat, 0), isNull);
    });

    test('whatsMissing: shown has n, missing is absent', () {
      final r = CardRounds.whatsMissing(_deck, 4, 9);
      expect(r.shown.length, 4);
      expect(r.shown.map((c) => c.id), isNot(contains(r.missing.id)));
    });

    test('draw: n distinct cards', () {
      final d = CardRounds.draw(_deck, 3, 5);
      expect(d.length, 3);
      expect(d.map((c) => c.id).toSet().length, 3);
    });

    test('byLetter / byCategory group correctly', () {
      expect(CardRounds.byCategory(_deck)['food']!.length, 4);
      expect(CardRounds.byLetter(_deck)['b']!.map((c) => c.id), containsAll(['banana', 'ball', 'bat']));
    });
  });
}
