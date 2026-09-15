import 'package:differentworld/features/games/data_seeded_game.dart';
import 'package:differentworld/features/games/games/picker_game.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seeds Spotlight from the live roster (Drift, not the content bank), then
/// hands off to the unified runner / live screen via [DataSeededGame]
/// (docs/VISION.md #18 — data-driven presentables read their data in a wrapper
/// and pass it as the seed). The resolved names ride in the wire-state, so a
/// joined controller shows the same pick.
class PickerScreen extends ConsumerWidget {
  const PickerScreen({required this.live, super.key});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DataSeededGame(
      def: const PickerGame(),
      live: live,
      data: ref.watch(subjectsInSpaceProvider),
      // Through the game, so the fair bag is dealt exactly once and the
      // same way wherever a round starts — the seeded-path-is-the-app-path
      // rule (CLAUDE.md).
      // DataSeededGame re-runs this on "Spin again"/replay, so a fresh round
      // deals a fresh bag — which is what starting over should mean.
      // A room has the children it has — no knob sizes this, so the values
      // are ignored rather than threaded somewhere with nothing to do.
      seed: (subjects, _) =>
          PickerGame.seedFor([for (final s in subjects) s.firstName]),
    );
  }
}
