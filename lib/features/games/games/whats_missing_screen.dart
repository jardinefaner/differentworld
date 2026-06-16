import 'package:differentworld/features/games/cards/card_rounds.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/data_seeded_game.dart';
import 'package:differentworld/features/games/games/whats_missing_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seeds What's Missing from the bundled picture deck (assets, not the content
/// bank), then hands off to the unified runner / live screen via
/// [DataSeededGame]. Each round is a 6-card set with one marked to hide; the
/// whole set + the hidden index ride the wire-state so a joined controller sees
/// the same board.
class WhatsMissingScreen extends ConsumerWidget {
  const WhatsMissingScreen({required this.live, super.key});

  final bool live;

  // Six cards per board (a 3×2 grid) — enough to be a real memory challenge,
  // few enough to study at a glance.
  static const int _perBoard = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DataSeededGame(
      def: const WhatsMissingGame(),
      live: live,
      data: ref.watch(pictureDeckProvider),
      seed: (cards) {
        if (cards.isEmpty) {
          return {'rounds': const <Map<String, dynamic>>[], 'i': 0, 'phase': 0, 'd': false};
        }
        // Up to 6 boards. Seed by deck size + a spread so present + control
        // derive the same boards from the same wire-state.
        final rounds = <Map<String, dynamic>>[];
        final per = cards.length < _perBoard ? cards.length : _perBoard;
        for (var k = 0; k < 6; k++) {
          final seed = cards.length + k * 53;
          // draw `per` cards for the board, then mark one to hide.
          final board = CardRounds.draw(cards, per, seed);
          if (board.length < 2) continue;
          final missing = seed % board.length;
          rounds.add({
            'cards': [
              for (final c in board) {'image': c.image, 'label': c.label},
            ],
            'missing': missing,
          });
        }
        return {'rounds': rounds, 'i': 0, 'phase': 0, 'd': false};
      },
    );
  }
}
