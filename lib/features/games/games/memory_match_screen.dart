import 'dart:math';

import 'package:differentworld/features/games/cards/card_rounds.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/data_seeded_game.dart';
import 'package:differentworld/features/games/games/memory_match_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seeds Memory / Match from the bundled picture deck (assets, not the content
/// bank): draw N distinct cards, double each into a pair, seeded-shuffle the
/// board, then hand off to the unified runner / live screen via
/// [DataSeededGame]. The shuffled board rides the wire-state so a joined
/// controller taps the same layout.
class MemoryMatchScreen extends ConsumerWidget {
  const MemoryMatchScreen({required this.live, super.key});

  final bool live;

  // Six pairs → a 4×3 board: a real challenge that still studies at a glance.
  static const int _pairs = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DataSeededGame(
      def: const MemoryMatchGame(),
      live: live,
      data: ref.watch(pictureDeckProvider),
      seed: (cards) {
        if (cards.length < 2) {
          return {
            'cards': const <Map<String, dynamic>>[],
            'flipped': const <int>[],
            'matched': const <int>[],
            'd': false,
          };
        }
        final picked = CardRounds.draw(cards, _pairs, cards.length);
        final board = <Map<String, dynamic>>[];
        for (final c in picked) {
          // Two copies share the source id as the match key.
          final card = {'image': c.image, 'label': c.label, 'pair': c.id};
          board
            ..add(Map<String, dynamic>.from(card))
            ..add(Map<String, dynamic>.from(card));
        }
        // Seeded shuffle so present + control derive the same layout.
        board.shuffle(Random(cards.length));
        return {
          'cards': board,
          'flipped': const <int>[],
          'matched': const <int>[],
          'd': false,
        };
      },
    );
  }
}
