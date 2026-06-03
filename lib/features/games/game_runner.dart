import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/activity_runtime/content_engine.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/games/game_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs a [GameDefinition] on a single device — the host-present, teacher-
/// controls path (`/activity/...`). Reads content ONCE (curated ∪ synced
/// AI/crowd, falling back to curated-only until the DB tier syncs), seeds a
/// [LocalGameController] from `def.initialState`, and hosts a [GameScaffold].
///
/// The live counterpart (a `LiveGameController` over `LiveSession` for the
/// `/live/...` routes) is Wave 0c — it slots into the same scaffold.
class GameRunner<S> extends ConsumerStatefulWidget {
  const GameRunner({required this.def, this.seed, super.key});

  final GameDefinition<S> def;

  /// Optional pre-built initial wire-state. Data-driven presentables (a
  /// picker over the roster, a Now & Next board over the schedule) read Drift
  /// via a provider in a wrapper and pass the seed here instead of going
  /// through `def.initialState` (which only sees the content bank).
  final Map<String, dynamic>? seed;

  @override
  ConsumerState<GameRunner<S>> createState() => _GameRunnerState<S>();
}

class _GameRunnerState<S> extends ConsumerState<GameRunner<S>> {
  late final LocalGameController _controller;

  @override
  void initState() {
    super.initState();
    // Our OWN bank instance → this session's seen-tracking is independent.
    final snapshot = ref.read(bankedContentProvider).value ?? curatedSeeds;
    _controller = LocalGameController(
      initial:
          widget.seed ?? widget.def.initialState(ContentEngine(snapshot)),
      reduce: widget.def.reduce,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      GameScaffold<S>(def: widget.def, controller: _controller);
}
