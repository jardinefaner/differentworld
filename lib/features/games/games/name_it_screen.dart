import 'package:differentworld/features/games/cards/card_rounds.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/data_seeded_game.dart';
import 'package:differentworld/features/games/games/name_it_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seed Name It from the bundled picture [cards] — a round of up to 12, drawn
/// ONCE so the present screen, the control, and a cast receiver all show the
/// same round. Shared by [NameItScreen] and the cockpit's cast tile.
Map<String, dynamic> nameItSeed(List<PictureCard> cards) {
  if (cards.isEmpty) {
    return {
      'cards': const <Map<String, String>>[],
      'i': 0,
      'r': false,
      'd': false,
    };
  }
  final picked = CardRounds.draw(cards, 12, cards.length);
  return {
    'cards': [
      for (final c in picked) {'image': c.image, 'label': c.label},
    ],
    'i': 0,
    'r': false,
    'd': false,
  };
}

/// Seeds Name It from the bundled picture deck (assets, not the content bank),
/// then hands off to the unified runner / live screen via [DataSeededGame]. The
/// drawn cards ride in the wire-state so a joined controller shows the same
/// round.
class NameItScreen extends ConsumerWidget {
  const NameItScreen({required this.live, super.key});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DataSeededGame(
      def: const NameItGame(),
      live: live,
      data: ref.watch(pictureDeckProvider),
      seed: nameItSeed,
    );
  }
}
