import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/live_session/live_game_screen.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Presents a [GameDefinition] either single-device ([GameRunner]) or live
/// ([LiveGameScreen]). The one branch every `/present/*` vs `/live/*` pair
/// shares — kept in one place so the two paths can't drift.
class GameSurface<S> extends StatelessWidget {
  const GameSurface({
    required this.def,
    required this.live,
    this.seed,
    super.key,
  });

  final GameDefinition<S> def;
  final bool live;
  final Map<String, dynamic>? seed;

  @override
  Widget build(BuildContext context) => live
      ? LiveGameScreen<S>(def: def, seed: seed)
      : GameRunner<S>(def: def, seed: seed);
}

/// A data-driven presentable (docs/VISION.md #18): read [data] from Drift,
/// build the wire-state [seed] from it, then hand off to the unified runner /
/// live screen. Centralizes the `.when()` + loading/error + live branch the
/// Spotlight / Now-&-Next wrappers used to each repeat.
class DataSeededGame<S, T> extends StatelessWidget {
  const DataSeededGame({
    required this.def,
    required this.live,
    required this.data,
    required this.seed,
    super.key,
  });

  final GameDefinition<S> def;
  final bool live;
  final AsyncValue<T> data;
  final Map<String, dynamic> Function(T data) seed;

  @override
  Widget build(BuildContext context) => data.when(
    data: (d) => GameSurface<S>(def: def, live: live, seed: seed(d)),
    loading: () => const EdgeScaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
    // Cold start / error: present the game empty rather than block — its
    // own empty handling covers the no-content case.
    error: (_, _) => GameSurface<S>(def: def, live: live),
  );
}
