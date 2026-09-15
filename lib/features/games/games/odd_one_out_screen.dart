import 'package:differentworld/features/games/cards/card_rounds.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/data_seeded_game.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/games/odd_one_out_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Eight rounds was typed once.
const int oddOneOutDefaultRounds = 8;

/// Seed Odd One Out from the bundled picture [cards] — rounds of three from a
/// category plus a stranger, built ONCE so present + control + a cast receiver
/// see the same four cards. Shared by [OddOneOutScreen] and the cockpit's cast
/// tile.
Map<String, dynamic> oddOneOutSeed(
  List<PictureCard> cards, [
  Map<String, Object?> values = const {},
]) {
  if (cards.isEmpty) {
    return {
      'rounds': const <Map<String, dynamic>>[],
      'i': 0,
      'r': false,
      'd': false,
    };
  }
  // Spread the seeds so consecutive rounds pick different categories; seed by
  // deck size so present + control derive the same set from the wire-state.
  final rounds = <Map<String, dynamic>>[];
  final want = roundsFrom(values, fallback: oddOneOutDefaultRounds);
  // The 24 is a try-limit, not a length: a category short of four cards
  // yields no round, so the builder asks more times than it needs.
  for (var k = 0; k < want * 3 && rounds.length < want; k++) {
    final r = CardRounds.oddOneOut(cards, cards.length + k * 31);
    if (r == null) continue;
    rounds.add({
      'cards': [
        for (final c in r.options) {'image': c.image, 'label': c.label},
      ],
      'answer': r.answer,
    });
  }
  return {'rounds': rounds, 'i': 0, 'n': rounds.length, 'r': false, 'd': false};
}

/// Seeds Odd One Out from the bundled picture deck (assets, not the content
/// bank), then hands off to the unified runner / live screen via
/// [DataSeededGame]. Each round (3 from a category + 1 stranger) rides in the
/// wire-state so a joined controller sees the same four cards.
class OddOneOutScreen extends ConsumerWidget {
  const OddOneOutScreen({required this.live, super.key});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DataSeededGame(
      def: const OddOneOutGame(),
      live: live,
      data: ref.watch(pictureDeckProvider),
      seed: oddOneOutSeed,
    );
  }
}
