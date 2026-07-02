import 'package:differentworld/features/game_content/custom_pictures.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/grid_reveal_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hosts "Reveal the Picture" on a single device, threading the library's
/// "Mix with the built-in emoji" toggle into the game via the runner's
/// `initialValues`. The staff photos themselves ride the content bank, so the
/// game reads them straight from its ContentSource — this wrapper only carries
/// the mix preference (which isn't a visible game setting).
class GridRevealScreen extends ConsumerWidget {
  const GridRevealScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mixEmoji = ref.watch(gridMixEmojiProvider).value ?? true;
    return GameRunner<GridRevealState>(
      def: const GridRevealGame(),
      initialValues: {'mixEmoji': mixEmoji},
    );
  }
}
