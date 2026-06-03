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
      seed: (subjects) => {
        'names': [for (final s in subjects) s.firstName],
        'i': 0,
        'spun': false,
      },
    );
  }
}
