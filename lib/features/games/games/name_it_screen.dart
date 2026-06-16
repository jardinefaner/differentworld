import 'package:differentworld/features/games/cards/card_rounds.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/data_seeded_game.dart';
import 'package:differentworld/features/games/games/name_it_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      seed: (cards) {
        if (cards.isEmpty) {
          return {'cards': const <Map<String, String>>[], 'i': 0, 'r': false, 'd': false};
        }
        // A round of up to 12. Seed by deck size so present + control derive
        // the same draw from the same wire-state (the round is built once and
        // broadcast).
        final picked = CardRounds.draw(cards, 12, cards.length);
        return {
          'cards': [
            for (final c in picked) {'image': c.image, 'label': c.label},
          ],
          'i': 0,
          'r': false,
          'd': false,
        };
      },
    );
  }
}
