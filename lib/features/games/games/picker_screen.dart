import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/picker_game.dart';
import 'package:differentworld/features/live_session/live_game_screen.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seeds Spotlight from the live roster (Drift, not the content bank), then
/// hands off to the single-device runner or the live screen (docs/VISION.md
/// #18 — data-driven presentables read their data in a wrapper and pass it as
/// the seed). The resolved names ride in the wire-state, so a joined
/// controller shows the same pick.
class PickerScreen extends ConsumerWidget {
  const PickerScreen({required this.live, super.key});

  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(subjectsInSpaceProvider);
    return roster.when(
      data: (subjects) {
        final seed = <String, dynamic>{
          'names': [for (final s in subjects) s.firstName],
          'i': 0,
          'spun': false,
        };
        return live
            ? LiveGameScreen(def: const PickerGame(), seed: seed)
            : GameRunner(def: const PickerGame(), seed: seed);
      },
      loading: () => const EdgeScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => live
          ? const LiveGameScreen(def: PickerGame())
          : const GameRunner(def: PickerGame()),
    );
  }
}
