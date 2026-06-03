import 'dart:async';

import 'package:differentworld/features/activity_runtime/presenter_shortcuts.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/games/game_fullscreen.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The familiar shell every game wears (docs/GAMES.md, VISION #17). It owns
/// what's copy-pasted across the deck — the control bar/panel, progress,
/// the keyboard wiring, the responsive present/control split, the cast
/// action — driving everything through one [GameController]. Each game
/// brings only its stage (`def.buildStage`) + its character (`def.vibe`).
///
/// The same scaffold renders a [LocalGameController] (single device) or a
/// live controller (Wave 0c, over `LiveSession`) with no change — the seam
/// that makes a game controllable AND live the moment its reducer exists.
class GameScaffold<S> extends StatelessWidget {
  const GameScaffold({
    required this.def,
    required this.controller,
    super.key,
  });

  static const _wideBreakpoint = 720.0;

  final GameDefinition<S> def;
  final GameController controller;

  void _send(GameIntent intent) => controller.send(intent);

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      actions: [
        SecondaryActionButton(
          tooltip: 'Fullscreen',
          icon: Icons.fullscreen,
          onPressed: () => unawaited(
            GameFullscreenScreen.open(
              context,
              def: def,
              controller: controller,
            ),
          ),
        ),
        if (def.liveRoute case final route?)
          SecondaryActionButton(
            tooltip: 'Present on a big screen',
            icon: Icons.cast,
            onPressed: () => unawaited(context.push(route)),
          ),
      ],
      body: StreamBuilder<Map<String, dynamic>>(
        stream: controller.states,
        initialData: controller.state,
        builder: (context, snapshot) {
          final wire = snapshot.data ?? controller.state;
          final state = def.decode(wire);
          final active = def.activeIntents(state);
          final done = wire['d'] == true;
          // Keyboard control for a laptop/projector host
          // (docs/PLATFORM_RUBRIC.md, P3): ← back · Space reveal · → / Enter
          // next · Space/+/= tally. Each binds only when its intent is live.
          return PresenterShortcuts(
            onBack: active.contains(GameIntent.back)
                ? () => _send(GameIntent.back)
                : null,
            onReveal: active.contains(GameIntent.reveal)
                ? () => _send(GameIntent.reveal)
                : null,
            onNext: active.contains(GameIntent.next)
                ? () => _send(GameIntent.next)
                : null,
            onTally: active.contains(GameIntent.tally)
                ? () => _send(GameIntent.tally)
                : null,
            child: ColoredBox(
              color: def.vibe.surface,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= _wideBreakpoint;
                  final stage = def.buildStage(context, state);
                  final revealLabel = def.revealLabel(revealed: wire['r'] == true);
                  // Full control override (poll, timer, …): one layout — the
                  // stage fills, the game's own controls sit in the bar.
                  final custom = def.buildControls(context, state, controller.send);
                  if (custom != null) {
                    return Column(
                      children: [
                        Expanded(child: stage),
                        _CustomControlBar(child: custom),
                      ],
                    );
                  }
                  return wide
                      ? Column(
                          children: [
                            Expanded(child: stage),
                            _GameControlBar(
                              wire: wire,
                              done: done,
                              active: active,
                              revealLabel: revealLabel,
                              onIntent: _send,
                            ),
                          ],
                        )
                      : SafeArea(
                          child: Column(
                            children: [
                              SizedBox(height: 220, child: stage),
                              Expanded(
                                child: _GameControlPanel(
                                  wire: wire,
                                  done: done,
                                  active: active,
                                  revealLabel: revealLabel,
                                  onIntent: _send,
                                ),
                              ),
                            ],
                          ),
                        );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

int _intOf(Map<String, dynamic> m, String k, int fallback) =>
    (m[k] as num?)?.toInt() ?? fallback;

/// Default wide control bar — slim, for the bottom of the presentation.
/// Standard affordances (Back · Reveal · Next, or Again when done) gated by
/// the game's [active] intents. A game that needs custom controls overrides
/// `buildControls` instead. Faithful to the archetype so progress reads
/// "i / n".
class _GameControlBar extends StatelessWidget {
  const _GameControlBar({
    required this.wire,
    required this.done,
    required this.active,
    required this.revealLabel,
    required this.onIntent,
  });

  final Map<String, dynamic> wire;
  final bool done;
  final Set<GameIntent> active;
  final String revealLabel;
  final void Function(GameIntent) onIntent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = _intOf(wire, 'i', 0);
    final total = _intOf(wire, 'n', 1);
    final revealed = wire['r'] == true;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                done ? 'Done' : '${index + 1} / $total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: active.contains(GameIntent.back)
                    ? () => onIntent(GameIntent.back)
                    : null,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
              const SizedBox(width: 8),
              if (done)
                FilledButton.icon(
                  onPressed: () => onIntent(GameIntent.reset),
                  icon: const Icon(Icons.replay),
                  label: const Text('Again'),
                )
              else ...[
                FilledButton.tonalIcon(
                  onPressed: active.contains(GameIntent.reveal)
                      ? () => onIntent(GameIntent.reveal)
                      : null,
                  icon: Icon(
                    revealed ? Icons.visibility_off : Icons.lightbulb_outline,
                  ),
                  label: Text(revealLabel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: active.contains(GameIntent.next)
                      ? () => onIntent(GameIntent.next)
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Default phone control panel — big, the phone is the remote.
class _GameControlPanel extends StatelessWidget {
  const _GameControlPanel({
    required this.wire,
    required this.done,
    required this.active,
    required this.revealLabel,
    required this.onIntent,
  });

  final Map<String, dynamic> wire;
  final bool done;
  final Set<GameIntent> active;
  final String revealLabel;
  final void Function(GameIntent) onIntent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = _intOf(wire, 'i', 0);
    final total = _intOf(wire, 'n', 1);
    final revealed = wire['r'] == true;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            done ? 'Done' : 'Slide ${index + 1} of $total',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (done)
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: () => onIntent(GameIntent.reset),
                icon: const Icon(Icons.replay),
                label: const Text('Start over'),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton.icon(
                onPressed: active.contains(GameIntent.next)
                    ? () => onIntent(GameIntent.next)
                    : null,
                icon: const Icon(Icons.arrow_forward, size: 28),
                label: const Text(
                  'Next',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: active.contains(GameIntent.back)
                        ? () => onIntent(GameIntent.back)
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: active.contains(GameIntent.reveal)
                        ? () => onIntent(GameIntent.reveal)
                        : null,
                    icon: Icon(
                      revealed
                          ? Icons.visibility_off
                          : Icons.lightbulb_outline,
                    ),
                    label: Text(revealLabel),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Wraps a game's custom `buildControls` widget in the standard bar chrome.
class _CustomControlBar extends StatelessWidget {
  const _CustomControlBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: child,
        ),
      ),
    );
  }
}
