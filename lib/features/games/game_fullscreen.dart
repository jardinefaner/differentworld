import 'dart:async';

import 'package:differentworld/features/activity_runtime/presenter_shortcuts.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fullscreen "present on the big screen" mode for ANY game. Pushed on the
/// ROOT navigator (above the app shell → the omnibox bar + chrome are gone)
/// with the system bars hidden (immersive). The stage fills the whole display
/// for the room; a tap reveals the controls + a close button, which auto-hide
/// after a few seconds so the room sees a clean stage. Drives the SAME
/// controller as the scaffold it launched from, so the presenter keeps
/// driving without leaving fullscreen.
class GameFullscreenScreen<S> extends StatefulWidget {
  const GameFullscreenScreen({
    required this.def,
    required this.controller,
    this.joinCode,
    super.key,
  });

  final GameDefinition<S> def;
  final GameController controller;

  /// The live join code, shown in the revealed overlay so late joiners can
  /// still get it. Null for a single-device present.
  final String? joinCode;

  /// Push on the ROOT navigator — escapes the shell so it's truly full-bleed.
  static Future<void> open<S>(
    BuildContext context, {
    required GameDefinition<S> def,
    required GameController controller,
    String? joinCode,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => GameFullscreenScreen<S>(
          def: def,
          controller: controller,
          joinCode: joinCode,
        ),
      ),
    );
  }

  @override
  State<GameFullscreenScreen<S>> createState() =>
      _GameFullscreenScreenState<S>();
}

class _GameFullscreenScreenState<S> extends State<GameFullscreenScreen<S>> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // Restore the app's default (EdgeScaffold draws under the bars).
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggle() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _send(GameIntent intent, [Map<String, dynamic> args = const {}]) {
    widget.controller.send(intent, args);
    _showControls(); // keep controls up + reset the timer while driving
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    return Scaffold(
      backgroundColor: def.vibe.surface,
      body: StreamBuilder<Map<String, dynamic>>(
        stream: widget.controller.states,
        initialData: widget.controller.state,
        builder: (context, snapshot) {
          final wire = snapshot.data ?? widget.controller.state;
          final state = def.decode(wire);
          final active = def.activeIntents(state);
          // Keyboard control for a real projector host (same bindings as the
          // scaffold). Showing controls on a keystroke keeps them findable.
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: def.buildStage(context, state)),
                  _Fade(
                    visible: _controlsVisible,
                    child: SafeArea(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.joinCode != null)
                                _CodeChip(code: widget.joinCode!),
                              IconButton(
                                tooltip: 'Exit fullscreen',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.fullscreen_exit,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _Fade(
                    visible: _controlsVisible,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _Controls<S>(
                        def: def,
                        wire: wire,
                        state: state,
                        active: active,
                        send: _send,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fade + ignore-pointer wrapper for the auto-hiding overlay.
class _Fade extends StatelessWidget {
  const _Fade({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: child,
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CODE  ',
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bottom control strip over a readability gradient. Uses the game's own
/// `buildControls` when present, else a compact standard bar from
/// [active] intents — the same vocabulary every game already speaks.
class _Controls<S> extends StatelessWidget {
  const _Controls({
    required this.def,
    required this.wire,
    required this.state,
    required this.active,
    required this.send,
  });

  final GameDefinition<S> def;
  final Map<String, dynamic> wire;
  final S state;
  final Set<GameIntent> active;
  final void Function(GameIntent intent, [Map<String, dynamic> args]) send;

  @override
  Widget build(BuildContext context) {
    final custom = def.buildControls(context, state, send);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
          child: custom ?? _standardBar(context),
        ),
      ),
    );
  }

  Widget _standardBar(BuildContext context) {
    final done = wire['d'] == true;
    final revealed = wire['r'] == true;
    return Row(
      children: [
        if (wire['n'] != null)
          Text(
            done
                ? 'Done'
                : '${((wire['i'] as num?)?.toInt() ?? 0) + 1} / '
                    '${(wire['n'] as num?)?.toInt() ?? 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        const Spacer(),
        if (active.contains(GameIntent.back))
          IconButton.filledTonal(
            onPressed: () => send(GameIntent.back),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
        if (active.contains(GameIntent.reveal)) ...[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => send(GameIntent.reveal),
            icon: Icon(revealed ? Icons.visibility_off : Icons.lightbulb_outline),
            label: Text(def.revealLabel(revealed: revealed)),
          ),
        ],
        if (active.contains(GameIntent.next)) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => send(GameIntent.next),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
          ),
        ],
        if (active.contains(GameIntent.reset)) ...[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => send(GameIntent.reset),
            icon: const Icon(Icons.replay),
            label: const Text('Again'),
          ),
        ],
      ],
    );
  }
}
