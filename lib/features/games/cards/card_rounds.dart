import 'dart:math';

import 'package:differentworld/features/games/cards/picture_card.dart';

/// Pure round-generators (docs/CARD_GAMES.md): a deck of [PictureCard]s in → a
/// game's round out. Every method is **seeded** (pass an int) so the present +
/// control devices derive the SAME round from the same wire-state seed — no
/// cross-device content sync. These plug into each card game's `initialState`;
/// the games stay pure `GameDefinition`s.
abstract final class CardRounds {
  /// One hidden card — Reveal the Picture, Name It.
  static PictureCard hidden(List<PictureCard> deck, int seed) =>
      deck[Random(seed).nextInt(deck.length)];

  /// Up to [n] this-or-that pairs (Image-or-That). No card appears twice.
  static List<(PictureCard, PictureCard)> pairs(
    List<PictureCard> deck,
    int n,
    int seed,
  ) {
    final pool = [...deck]..shuffle(Random(seed));
    final out = <(PictureCard, PictureCard)>[];
    for (var i = 0; i + 1 < pool.length && out.length < n; i += 2) {
      out.add((pool[i], pool[i + 1]));
    }
    return out;
  }

  /// 3 same-category cards + 1 from a DIFFERENT category. `answer` indexes the
  /// odd one. Null when the deck lacks a category with ≥3 cards plus a second
  /// non-empty category.
  static ({List<PictureCard> options, int answer})? oddOneOut(
    List<PictureCard> deck,
    int seed,
  ) {
    final r = Random(seed);
    final byCat = byCategory(deck);
    final big = byCat.entries.where((e) => e.value.length >= 3).toList();
    if (big.isEmpty) return null;
    final main = big[r.nextInt(big.length)];
    final otherCats = byCat.entries
        .where((e) => e.key != main.key && e.value.isNotEmpty)
        .toList();
    if (otherCats.isEmpty) return null;
    final three = ([...main.value]..shuffle(r)).take(3).toList();
    final oddCat = otherCats[r.nextInt(otherCats.length)];
    final odd = ([...oddCat.value]..shuffle(r)).first;
    final options = [...three, odd]..shuffle(r);
    return (options: options, answer: options.indexOf(odd));
  }

  /// A set of [n] cards with one removed — What's Missing. `shown` has [n];
  /// `missing` is not in `shown`.
  static ({List<PictureCard> shown, PictureCard missing}) whatsMissing(
    List<PictureCard> deck,
    int n,
    int seed,
  ) {
    final pool = ([...deck]..shuffle(Random(seed))).take(n + 1).toList();
    final missing = pool.removeLast();
    return (shown: pool, missing: missing);
  }

  /// [n] distinct random draws — Three-Card Story, Act It Out.
  static List<PictureCard> draw(List<PictureCard> deck, int n, int seed) =>
      ([...deck]..shuffle(Random(seed))).take(n).toList();

  /// Group by first letter — phonics / Beat-the-Letter.
  static Map<String, List<PictureCard>> byLetter(List<PictureCard> deck) {
    final m = <String, List<PictureCard>>{};
    for (final c in deck) {
      (m[c.letter] ??= <PictureCard>[]).add(c);
    }
    return m;
  }

  /// Group by category — Sort It / odd-one-out distractors.
  static Map<String, List<PictureCard>> byCategory(List<PictureCard> deck) {
    final m = <String, List<PictureCard>>{};
    for (final c in deck) {
      (m[c.category] ??= <PictureCard>[]).add(c);
    }
    return m;
  }
}
