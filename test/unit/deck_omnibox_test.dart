// Every card in the Do-together library is reachable from the omnibox —
// exactly once. Before this, one of forty-one was: a teacher who typed
// "bingo" found nothing, and a game only existed if you already knew which
// deck it was on.

import 'package:differentworld/features/activity_runtime/activity_deck.dart';
import 'package:differentworld/features/omnibox/deck_entries.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every deck card is searchable, and none twice', () {
    final cards = [...breakDeck(camera: true), ...presentDeck];
    final generated = deckEntries(camera: true);
    final generatedRoutes = <String>{};
    for (final e in generated) {
      expect(e.keywords, isNotEmpty, reason: e.label);
      expect(e.subtitle, isNotNull, reason: e.label);
      generatedRoutes.add(e.id);
    }
    // Generated + hand-listed covers every card...
    for (final c in cards) {
      final byHand = alreadyListed.contains(c.route);
      final byGenerator = generated.any((e) => e.label == c.title);
      expect(
        byHand || byGenerator,
        isTrue,
        reason: '${c.title} (${c.route}) is not searchable',
      );
      expect(
        byHand && byGenerator,
        isFalse,
        reason: '${c.title} is listed twice',
      );
    }
    // ...and ids are unique.
    expect(generatedRoutes.length, generated.length);
  });

  test('the camera card follows the platform', () {
    expect(
      deckEntries(camera: true).any((e) => e.label == 'Photo Studio'),
      isTrue,
    );
    expect(
      deckEntries(camera: false).any((e) => e.label == 'Photo Studio'),
      isFalse,
    );
  });

  test('a half-remembered name still finds the game', () {
    final entries = deckEntries(camera: true);
    bool finds(String word, String title) => entries.any(
      (e) => e.label == title && e.keywords.any((k) => k.contains(word)),
    );
    expect(finds('would you rather', 'This or That'), isTrue);
    expect(finds('simon says', 'Simon'), isTrue);
    expect(finds('mad libs', 'Fill in the Blank'), isTrue);
    expect(finds('four in a row', 'Connect Four'), isTrue);
  });
}
