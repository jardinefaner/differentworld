import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_stage.dart';
import 'package:flutter/material.dart';

/// Visual Timer — the foundational "time" primitive (docs/VISION.md #18): a big
/// countdown on the room screen, driven from the phone (Start / Pause / +1 min
/// / Reset). The first castable surface that ISN'T a game.
///
/// Self-contained: the wire carries an absolute END time (ms); the receiver
/// ticks LOCALLY toward it, so there's no per-second broadcast — only the
/// control taps (start / pause / extend) cross the wire. Realtime latency is a
/// blip against a minutes-long timer, so the room screen and the phone read the
/// same number.
class TimerState {
  const TimerState({
    required this.initSecs,
    required this.remainingSecs,
    required this.endAtMs,
    required this.running,
  });

  factory TimerState.fromMap(Map<String, dynamic> m) => TimerState(
        initSecs: (m['init'] as num?)?.toInt() ?? 300,
        remainingSecs: (m['rem'] as num?)?.toInt() ?? 300,
        endAtMs: (m['end'] as num?)?.toInt(),
        running: m['run'] == true,
      );

  final int initSecs;

  /// Authoritative when PAUSED (the frozen remaining seconds).
  final int remainingSecs;

  /// Authoritative when RUNNING (absolute epoch-ms the timer hits zero).
  final int? endAtMs;
  final bool running;
}

class TimerGame extends GameDefinition<TimerState> {
  const TimerGame();

  @override
  bool get seedsFromContentBank => false;

  @override
  String get id => 'timer';

  @override
  String get title => 'Timer';

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.slate);

  @override
  String? get liveRoute => '/live/timer';

  /// Default 5:00, paused.
  @override
  Map<String, dynamic> initialState(ContentSource content) =>
      const {'init': 300, 'rem': 300, 'end': null, 'run': false};

  @override
  TimerState decode(Map<String, dynamic> state) => TimerState.fromMap(state);

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final s = Map<String, dynamic>.from(state);
    final init = (s['init'] as num?)?.toInt() ?? 300;
    final rem = (s['rem'] as num?)?.toInt() ?? init;
    final end = (s['end'] as num?)?.toInt();
    final run = s['run'] == true;
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (intent) {
      case GameIntent.reveal: // Start / Pause toggle (the primary control).
        if (run && end != null) {
          s['rem'] = ((end - now) / 1000).round().clamp(0, 1 << 30);
          s['end'] = null;
          s['run'] = false;
        } else {
          s['end'] = now + rem * 1000;
          s['run'] = true;
        }
      case GameIntent.tally: // +1 minute.
        if (run && end != null) {
          s['end'] = end + 60000;
        } else {
          s['rem'] = rem + 60;
        }
      case GameIntent.reset:
        s['rem'] = init;
        s['end'] = null;
        s['run'] = false;
      case GameIntent.next:
      case GameIntent.back:
      case GameIntent.pick:
      case GameIntent.capture:
      case GameIntent.submit:
        break;
    }
    return s;
  }

  @override
  Set<GameIntent> activeIntents(TimerState s) =>
      {GameIntent.reveal, GameIntent.tally, GameIntent.reset};

  @override
  Widget buildStage(BuildContext context, TimerState s) =>
      _TimerStage(state: s, accent: vibe.accent);

  @override
  Widget? buildControls(
    BuildContext context,
    TimerState state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => send(GameIntent.reveal),
            icon: Icon(state.running ? Icons.pause : Icons.play_arrow),
            label: Text(state.running ? 'Pause' : 'Start'),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () => send(GameIntent.tally),
          child: const Text('+1 min'),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () => send(GameIntent.reset),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}

/// The ticking stage — rendered on the room screen. Ticks locally toward the
/// wire's `endAtMs` while running; static when paused.
class _TimerStage extends StatefulWidget {
  const _TimerStage({required this.state, required this.accent});

  final TimerState state;
  final Color accent;

  @override
  State<_TimerStage> createState() => _TimerStageState();
}

class _TimerStageState extends State<_TimerStage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_TimerStage old) {
    super.didUpdateWidget(old);
    // Re-sync ONLY when the timer-relevant state changed — an unrelated parent
    // rebuild shouldn't cancel + recreate the ticker (a spurious 250ms stall).
    if (old.state.running != widget.state.running ||
        old.state.endAtMs != widget.state.endAtMs ||
        old.state.remainingSecs != widget.state.remainingSecs) {
      _sync();
    }
  }

  // Tick only while running; a fresh wire (pause / extend) re-syncs the ticker.
  void _sync() {
    _ticker?.cancel();
    if (widget.state.running) {
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        setState(() {});
        // Stop at zero so "Time!" doesn't rebuild forever; +1 min / reset sends
        // a fresh wire that re-syncs the ticker.
        if (_remaining <= 0) _ticker?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _remaining {
    final s = widget.state;
    if (s.running && s.endAtMs != null) {
      return ((s.endAtMs! - DateTime.now().millisecondsSinceEpoch) / 1000)
          .ceil()
          .clamp(0, 1 << 30);
    }
    return s.remainingSecs;
  }

  @override
  Widget build(BuildContext context) {
    final secs = _remaining;
    final done = secs <= 0;
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    final theme = Theme.of(context);
    return GameStage.frame(
      context,
      eyebrow: done
          ? "Time's up"
          : (widget.state.running ? 'Counting down' : 'Paused'),
      hero: Text(
        done ? 'Time!' : '$mm:$ss',
        textAlign: TextAlign.center,
        style: theme.textTheme.displayLarge?.copyWith(
          color: done ? widget.accent : Colors.white,
          fontWeight: FontWeight.w400,
          fontSize: 120,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
