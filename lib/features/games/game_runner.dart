import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/activity_runtime/content_engine.dart';
import 'package:differentworld/features/facilitation/run_script_wire.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_clock.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/games/game_scaffold.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/game_settings_sheet.dart';
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
  const GameRunner({
    required this.def,
    this.seed,
    this.reseed,
    this.initialValues,
    super.key,
  });

  final GameDefinition<S> def;

  /// Optional pre-built initial wire-state. Data-driven presentables (a
  /// picker over the roster, a Now & Next board over the schedule) read Drift
  /// via a provider in a wrapper and pass the seed here instead of going
  /// through `def.initialState` (which only sees the content bank).
  final Map<String, dynamic>? seed;

  /// A fresh [seed] for "Play again", when the wrapper can make one.
  ///
  /// Without it a seeded game resets through the reducer, and `GridGame`'s
  /// reset turns every square face-DOWN — right for Minesweeper, wrong for
  /// a board that is played face-up: a deck-seeded Bingo's second round was
  /// sixteen dark tiles with the pictures gone. The wrapper that built the
  /// first board builds the next one.
  final Map<String, dynamic> Function()? reseed;

  /// Optional overrides for the game's setting values, merged over the
  /// defaults. Lets a wrapper thread a preference the game reads at seed time
  /// but that isn't a visible setting (e.g. Reveal-the-Picture's "mix in the
  /// built-in emoji" toggle, read from SharedPreferences). Reseed ("play
  /// again") keeps honoring these — they live in `_values`.
  final Map<String, Object?>? initialValues;

  @override
  ConsumerState<GameRunner<S>> createState() => _GameRunnerState<S>();
}

class _GameRunnerState<S> extends ConsumerState<GameRunner<S>> {
  late final LocalGameController _controller;
  late final ContentEngine _engine;

  /// The clock, for the games that have one (the mole moves on its own).
  /// Null for every other game, which is most of them.
  final _clock = GameClock();
  // Teacher-chosen settings (the Settings contract). Defaults until tuned;
  // the reseed closure reads this field, so "play again" + applied changes
  // both honor the current values.
  late Map<String, Object?> _values;

  @override
  void initState() {
    super.initState();
    // Our OWN bank instance → this session's seen-tracking is independent.
    // Keep the engine so "play again" pulls FRESH content from its never-
    // repeat memory (a new round, not the same questions).
    final snapshot = ref.read(bankedContentProvider).value ?? curatedSeeds;
    _engine = ContentEngine(snapshot);
    _values = {
      ...defaultSettingValues(widget.def.settings),
      ...?widget.initialValues,
    };
    _controller = LocalGameController(
      // The run-script's cursor lives in the WIRE, seeded here rather than in
      // 41 initialState overrides, and every intent goes through
      // RunScriptWire so the briefing behaves identically on this device and
      // on a paired screen.
      initial: RunScriptWire.seed(
        widget.def,
        widget.seed ?? widget.def.initialStateFor(_engine, _values),
      ),
      reduce: (state, intent, args) =>
          RunScriptWire.reduce(widget.def, state, intent, args),
      // Play again deals fresh content and goes STRAIGHT to the board — no
      // RunScriptWire.seed here. The runner's reseed bypasses the reducer, so
      // seeding the cursor in it re-briefed every round behind the wire rule
      // that says a room which just played does not need the rules again.
      reseed: widget.seed != null
          ? widget.reseed
          : () => widget.def.initialStateFor(_engine, _values),
    );
    // This State is the authority here (it owns the local reducer), so it
    // winds the clock. It used to do so with a bespoke timer that read
    // `ticks` off GridGame directly — the only clock in the app, which is
    // why three games froze on every other surface.
    // No `mounted` guard in the callback, deliberately: `dispose` stops the
    // clock on its FIRST line, and a cancelled periodic timer cannot fire
    // again, so there is no post-dispose window for one to land in.
    _clock.follow(widget.def, () => _controller.send(GameIntent.tick));
  }

  /// Open the settings sheet; applying starts a fresh round with the new
  /// values (the reseed closure reads [_values]).
  Future<void> _openSettings() async {
    final result = await showGameSettings(
      context,
      settings: widget.def.settings,
      initial: _values,
    );
    if (result == null || !mounted) return;
    setState(() => _values = result);
    _controller.send(GameIntent.reset);
  }

  @override
  void dispose() {
    _clock.stop();
    _controller.dispose();
    super.dispose();
  }

  // No GameMotion here: [GameView] provides the scope wherever a game is
  // drawn, reading the same Preferences switch. Two sources for one policy is
  // how the cockpit ended up with none at all.
  @override
  Widget build(BuildContext context) => GameScaffold<S>(
    def: widget.def,
    controller: _controller,
    onSettings: widget.def.settings.isEmpty ? null : _openSettings,
  );
}
