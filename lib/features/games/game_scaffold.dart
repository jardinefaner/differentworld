import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/presenter_shortcuts.dart';
import 'package:differentworld/features/class_memory/class_memory.dart';
import 'package:differentworld/features/facilitation/keep_this.dart';
import 'package:differentworld/features/facilitation/room_tools.dart';
import 'package:differentworld/features/facilitation/run_script_view.dart';
import 'package:differentworld/features/facilitation/run_script_wire.dart';
import 'package:differentworld/features/game_content/ours_strip.dart';
import 'package:differentworld/features/games/celebration.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/games/game_fullscreen.dart';
import 'package:differentworld/features/games/round_wrap.dart';
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
    this.onSettings,
    super.key,
  });

  static const _wideBreakpoint = 720.0;

  final GameDefinition<S> def;
  final GameController controller;

  /// Opens the game's settings sheet — null when the game has no settings.
  final VoidCallback? onSettings;

  void _send(GameIntent intent) => controller.send(intent);

  /// Back to beat one of the run-script, over whatever the board is doing.
  void _rules() =>
      controller.send(GameIntent.reveal, {RunScriptWire.rulesArg: true});

  static void _noSend(
    GameIntent intent, [
    Map<String, dynamic> args = const {},
  ]) {}

  @override
  Widget build(BuildContext context) {
    // Whether this game draws its own tappable stage (the classics, Memory,
    // Reveal the Picture). Those get NO control panel, so the two occasional
    // verbs the panel used to carry — Room tools and Start over — live in the
    // top pill for them instead. Probed once, with a no-op sender: the answer
    // does not change over a round.
    final ownsStage =
        def.buildLiveStage(context, def.decode(controller.state), _noSend) !=
        null;
    return EdgeScaffold(
      actions: [
        if (onSettings case final open?)
          SecondaryActionButton(
            tooltip: 'Game settings',
            icon: Icons.tune,
            onPressed: open,
          ),
        // The rules, one tap away for the whole round — because Play again no
        // longer re-briefs (run_script_wire.dart), this is where a substitute
        // who missed a beat goes back to it.
        if (def.howToPlay.isNotEmpty)
          SecondaryActionButton(
            tooltip: 'How to play',
            icon: Icons.help_outline,
            onPressed: _rules,
          ),
        if (ownsStage) ...[
          SecondaryActionButton(
            tooltip: 'Room tools',
            icon: Icons.handyman_outlined,
            onPressed: () => unawaited(showRoomTools(context)),
          ),
          SecondaryActionButton(
            tooltip: 'Start over',
            icon: Icons.replay,
            onPressed: () => _send(GameIntent.reset),
          ),
        ],
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
        // No per-game cast icon here: AppShell's CastChromeButton already
        // shows ONE cast affordance on every staff route (the persistent
        // anchor + join code), and its /cast cockpit can launch this game
        // directly (_castGame). A second cast icon in the same pill was the
        // "two cast icons" duplication.
      ],
      // The run-script comes FIRST when the game has one: the room is told
      // what it is about to play before the board appears, so a substitute
      // who does not know the game can still start it (room_beat.dart).
      body: StreamBuilder<Map<String, dynamic>>(
        stream: controller.states,
        initialData: controller.state,
        builder: (context, snapshot) {
          final wire = snapshot.data ?? controller.state;
          // The briefing comes first, and it reads from the WIRE so this
          // device and a paired room screen are never on different beats.
          if (RunScriptWire.indexOf(wire) case final at?) {
            final briefSurface = def.vibe.surface;
            return RunScriptView(
              script: def.howToPlay,
              index: at,
              title: def.title,
              surface: briefSurface,
              // Content-driven fill, so no theme governs the foreground — pick
              // by luminance or the pale vibes get white on light.
              onLine: AppColors.onAccent(briefSurface),
              onNext: () => _send(GameIntent.next),
              onBack: () => _send(GameIntent.back),
            );
          }
          final state = def.decode(wire);
          final active = def.activeIntents(state);
          final done = wire['d'] == true;
          // What this round leaves behind, if the game says it leaves
          // anything. Most say nothing, deliberately — a brain break is meant
          // to be ephemeral, and a class memory full of "Team 1 wins" buries
          // the few things worth keeping.
          final keepText = done ? def.keepsake(def.decode(wire)) : null;
          final keeper = (keepText == null || keepText.trim().isEmpty)
              ? null
              : KeepThisButton(
                  text: keepText,
                  sort: ClassMemorySort.discovery,
                  context_: def.title,
                  label: 'Keep what we made',
                );
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
                  // ONE device: the phone in the host's hand is the actor's
                  // card as well as the remote, so a game with a secret
                  // (Charades) shows the SECRET here — the word — and keeps
                  // `buildStage` (the category, never the word) for the
                  // fullscreen present and the cast receiver, which face the
                  // room. Before this Charades ran only as a two-device
                  // session and opened on a lobby; a substitute with one phone
                  // could not start it at all.
                  final stage =
                      def.buildSecretStage(context, state) ??
                      def.buildStage(context, state);
                  final revealLabel = def.revealLabel(
                    revealed: wire['r'] == true,
                  );
                  // The stage is the instrument (memory, reveal, what's
                  // missing): the game owns the whole single-device shape, so
                  // there is no second copy of the board to tap and no
                  // control bar to leave room for. Checked FIRST — a game
                  // that offers this also has a buildControls remote, which
                  // is for the cast cockpit, not for here.
                  final live = def.buildLiveStage(
                    context,
                    state,
                    controller.send,
                  );
                  if (live != null) {
                    // The end of the round, when there is one. The board
                    // stays on screen above it — the winning line is what
                    // the room wants to look at — and the beat carries the
                    // verbs the board games never had: again, done, rules.
                    return SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: CelebrationLayer(
                              done: done,
                              accent: def.vibe.accent,
                              child: live,
                            ),
                          ),
                          if (done)
                            RoundWrap(
                              key: const ValueKey('round-wrap'),
                              line: def.outcomeLine(state),
                              accent: def.vibe.accent,
                              gameId: def.id,
                              keepsake: keepText,
                              onAgain: () => _send(GameIntent.reset),
                              onDone: () {
                                if (context.canPop()) context.pop();
                              },
                              onRules: def.howToPlay.isEmpty ? null : _rules,
                            ),
                        ],
                      ),
                    );
                  }

                  // Full control override (poll, timer, …): one layout — the
                  // stage fills, the game's own controls sit in the bar.
                  final custom = def.buildControls(
                    context,
                    state,
                    controller.send,
                  );
                  // The same burst over every stage, from the framework:
                  // the eleventh game somebody adds celebrates like the
                  // first.
                  final celebrated = CelebrationLayer(
                    done: done,
                    accent: def.vibe.accent,
                    child: stage,
                  );
                  if (custom != null) {
                    return Column(
                      children: [
                        Expanded(child: celebrated),
                        _CustomControlBar(child: custom),
                      ],
                    );
                  }
                  return wide
                      ? Column(
                          children: [
                            Expanded(child: celebrated),
                            _GameControlBar(
                              gameId: def.id,
                              keepsake: keeper,
                              wire: wire,
                              done: done,
                              active: active,
                              revealLabel: revealLabel,
                              onIntent: _send,
                              onDone: () {
                                if (context.canPop()) context.pop();
                              },
                            ),
                          ],
                        )
                      : SafeArea(
                          child: Column(
                            children: [
                              // The stage takes every pixel the controls don't
                              // need. A fixed-height stage (was 220) clipped
                              // any game whose stage stacks vertically — the
                              // riddle prompt + its revealed answer card sat
                              // below the fold and read as "cut off" on
                              // phones.
                              Expanded(child: celebrated),
                              _GameControlPanel(
                                gameId: def.id,
                                keepsake: keeper,
                                wire: wire,
                                done: done,
                                active: active,
                                revealLabel: revealLabel,
                                onIntent: _send,
                                onDone: () {
                                  if (context.canPop()) context.pop();
                                },
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
    required this.gameId,
    required this.keepsake,
    required this.wire,
    required this.done,
    required this.active,
    required this.revealLabel,
    required this.onIntent,
    required this.onDone,
  });

  /// The game's id — the key the "add ours" door looks up.
  final String gameId;

  /// The end-of-round keeper, when this game produced something worth
  /// remembering. Null for most games, which is the point — see
  /// `GameDefinition.keepsake`.
  final Widget? keepsake;

  final Map<String, dynamic> wire;
  final bool done;
  final Set<GameIntent> active;
  final String revealLabel;
  final void Function(GameIntent) onIntent;

  /// Exit the game (pop back to the deck) — shown on the end-of-round state.
  final VoidCallback onDone;

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
          // A Wrap, not a Row: at the 200% text floor the status line plus
          // three intrinsically-sized buttons are wider than the 720dp
          // breakpoint, and a Row has nowhere to put the excess — it
          // overflowed by 280dp on the done beat before this changed, which
          // the gallery never caught because it doesn't render that state at
          // this width. Wrapping lets the buttons drop to a second run
          // instead of off the screen; at default scale it lays out
          // identically to the Row it replaces.
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                done ? 'Round complete!' : '${index + 1} / $total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Wrap(
                key: ValueKey(done ? 'bar-done' : 'bar-playing'),
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!done) const RoomToolsButton(compact: true),
                  if (!done)
                    IconButton.filledTonal(
                      onPressed: active.contains(GameIntent.back)
                          ? () => onIntent(GameIntent.back)
                          : null,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
                  if (done) ...[
                    OutlinedButton.icon(
                      onPressed: onDone,
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                    FilledButton.icon(
                      // reset reseeds with fresh content (LocalGameController).
                      onPressed: () => onIntent(GameIntent.reset),
                      icon: const Icon(Icons.replay),
                      label: const Text('Play again'),
                    ),
                    OursStrip(
                      key: const ValueKey('ours-strip-bar'),
                      route: gameId,
                      compact: true,
                    ),
                    ?keepsake,
                  ] else ...[
                    FilledButton.tonalIcon(
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
    required this.gameId,
    required this.keepsake,
    required this.wire,
    required this.done,
    required this.active,
    required this.revealLabel,
    required this.onIntent,
    required this.onDone,
  });

  /// The game's id — the key the "add ours" door looks up.
  final String gameId;

  /// The end-of-round keeper, when this game produced something worth
  /// remembering. Null for most games, which is the point — see
  /// `GameDefinition.keepsake`.
  final Widget? keepsake;

  final Map<String, dynamic> wire;
  final bool done;
  final Set<GameIntent> active;
  final String revealLabel;
  final void Function(GameIntent) onIntent;

  /// Exit the game (pop back to the deck) — shown on the end-of-round state.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = _intOf(wire, 'i', 0);
    final total = _intOf(wire, 'n', 1);
    final revealed = wire['r'] == true;
    // Same themed surface as the wide control bar. The panel used to sit
    // directly on the stage's near-black vibe surface while using THEME
    // text colors — in light mode that's dark-on-dark (unreadable), and
    // either way the controls looked locked to one brightness while the
    // rest of the app follows the system theme.
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              done ? 'Round complete!' : 'Slide ${index + 1} of $total',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (done) ...[
              // No caption under this: "Play again" already says what it
              // does, and at the 200% text floor the sentence cost three
              // lines that the stage above needed (CLAUDE.md, "make it
              // obvious first" — an instruction always on screen is a sign
              // on a wall).
              Icon(
                Icons.celebration_outlined,
                size: 44,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton.icon(
                  onPressed: () => onIntent(GameIntent.reset),
                  icon: const Icon(Icons.replay),
                  label: const Text(
                    'Play again',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.check),
                  label: const Text('Done'),
                ),
              ),
              OursStrip(key: const ValueKey('ours-strip-panel'), route: gameId),
              ?keepsake,
            ] else ...[
              // Pick a name, start a timer, flash "eyes up" — WITHOUT leaving
              // the activity. This is the whole point of facet 5: the
              // instruments were built and unreachable from in here.
              const Align(
                alignment: Alignment.centerLeft,
                child: RoomToolsButton(),
              ),
              const SizedBox(height: 4),
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
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
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

/// The themed strip a live stage puts its verbs on.
///
/// The stage itself is a RAW canvas — a projection surface, hardcoded dark by
/// docs/THEME_ADHERENCE.md. Its CONTROLS are not: a control region inside an
/// immersive surface is themed even though the stage around it is not, and
/// painting buttons straight onto the dark stage is the boundary bug that doc
/// names. It also just fails to read — an outlined button on near-black is a
/// rumour.
///
/// So a [GameDefinition.buildLiveStage] ends with this: the board takes every
/// pixel above it, the verbs sit on `surfaceContainerHighest` below, and the
/// SafeArea keeps them off the home indicator.
class GameVerbBar extends StatelessWidget {
  const GameVerbBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
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
