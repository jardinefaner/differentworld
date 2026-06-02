import 'dart:async';
import 'dart:math';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The GENERIC live present/control screen (docs/GAMES.md — "all games
/// speak the same language"). Give it any [GameDefinition] and that game is
/// live: a presenter (big screen) renders `def.buildStage` + drives the
/// reducer; a controller (phone) joins by code and sends the same
/// [GameIntent]s over a [LiveGameController]. Build this once → every game
/// on the framework gets present/control for free.
///
/// The lobby / join-code / presence chrome is the only live-specific part;
/// the stage and the control vocabulary come entirely from the game.
class LiveGameScreen<S> extends ConsumerStatefulWidget {
  const LiveGameScreen({required this.def, this.seed, super.key});

  final GameDefinition<S> def;

  /// Optional pre-built initial wire-state for data-driven presentables —
  /// the presenter seeds from Drift (roster/schedule); the controller gets it
  /// via the broadcast (self-describing state).
  final Map<String, dynamic>? seed;

  @override
  ConsumerState<LiveGameScreen<S>> createState() => _LiveGameScreenState<S>();
}

enum _Mode { lobby, present, control }

/// 4 chars, no ambiguous glyphs (0/O/1/I/L) — easy to read off a screen.
String generateSessionCode() {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = Random();
  return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
}

class _LiveGameScreenState<S> extends ConsumerState<LiveGameScreen<S>> {
  GameDefinition<S> get _def => widget.def;

  _Mode _mode = _Mode.lobby;
  LiveGameController? _controller;
  final _subs = <StreamSubscription<dynamic>>[];
  final _codeCtrl = TextEditingController();

  Map<String, dynamic> _wire = const {};
  int _peers = 0;
  LiveStatus _status = LiveStatus.connecting;

  void _open(SessionRole role, String code) {
    if (_controller != null) return; // re-entrancy: ignore a double-tap
    final snapshot = ref.read(bankedContentProvider).value ?? curatedSeeds;
    final c = LiveGameController.open(
      client: ref.read(supabaseProvider),
      role: role,
      code: code,
      def: _def,
      content: LocalContentBank(snapshot),
      seed: widget.seed,
    );
    _subs
      ..add(c.states.listen((v) {
        if (mounted) setState(() => _wire = v);
      }))
      ..add(c.peers.listen((v) {
        if (mounted) setState(() => _peers = v);
      }))
      ..add(c.status.listen((v) {
        if (mounted) setState(() => _status = v);
      }));
    setState(() {
      _controller = c;
      _wire = c.state;
      _mode = role == SessionRole.present ? _Mode.present : _Mode.control;
    });
  }

  void _leave() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    _controller?.dispose();
    _controller = null; // null BEFORE the mounted check so dispose() no-ops
    if (!mounted) return;
    setState(() {
      _mode = _Mode.lobby;
      _wire = const {};
      _peers = 0;
      _status = LiveStatus.connecting;
    });
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _controller?.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: const Color(0xFF11121A),
        child: SafeArea(
          child: switch (_mode) {
            _Mode.lobby => _lobby(context),
            _Mode.present => _stageView(context, isPresenter: true),
            _Mode.control => _stageView(context, isPresenter: false),
          },
        ),
      ),
    );
  }

  // ── Lobby ──────────────────────────────────────────────────────────────
  Widget _lobby(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_def.title} — Live',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Present on the big screen, control from your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 28),
              _LobbyCard(
                icon: Icons.cast,
                title: 'Present here',
                subtitle: 'This screen shows the game + a join code.',
                onTap: () => _open(SessionRole.present, generateSessionCode()),
              ),
              const SizedBox(height: 14),
              _JoinCard(
                controller: _codeCtrl,
                onJoin: (code) => _open(SessionRole.control, code),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stage (present + control share the game's stage + controls) ──────────
  Widget _stageView(BuildContext context, {required bool isPresenter}) {
    final c = _controller!;
    final state = _def.decode(_wire);
    // A game with custom controls (poll, timer) owns the bar; otherwise the
    // standard intents bar. Same override the single-device scaffold honors.
    final custom = _def.buildControls(context, state, c.send);
    return Column(
      children: [
        if (isPresenter)
          _PresenterHeader(
            code: c.code,
            peers: _peers,
            status: _status,
            onEnd: _leave,
          )
        else
          _ControllerHeader(status: _status, onLeave: _leave),
        Expanded(child: _def.buildStage(context, state)),
        if (custom != null)
          _CustomLiveBar(child: custom)
        else
          _LiveControls<S>(def: _def, wire: _wire, onIntent: c.send),
      ],
    );
  }
}

/// Wraps a game's custom `buildControls` in the dark live-bar chrome.
class _CustomLiveBar extends StatelessWidget {
  const _CustomLiveBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
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

/// The live control bar — dark-themed for the big screen / the phone remote,
/// rendered from the game's *active* [GameIntent]s so it fits any game shape
/// (reveal: Back·Reveal·Next; tally: +1·New; done: Again).
class _LiveControls<S> extends StatelessWidget {
  const _LiveControls({
    required this.def,
    required this.wire,
    required this.onIntent,
  });

  final GameDefinition<S> def;
  final Map<String, dynamic> wire;
  final void Function(GameIntent) onIntent;

  @override
  Widget build(BuildContext context) {
    final active = def.activeIntents(def.decode(wire));
    final index = (wire['i'] as num?)?.toInt() ?? 0;
    final total = (wire['n'] as num?)?.toInt() ?? 0;
    final done = wire['d'] == true;
    final revealed = wire['r'] == true;

    final buttons = <Widget>[
      if (active.contains(GameIntent.back))
        IconButton.filledTonal(
          onPressed: () => onIntent(GameIntent.back),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
      if (active.contains(GameIntent.reveal))
        FilledButton.tonalIcon(
          onPressed: () => onIntent(GameIntent.reveal),
          icon: Icon(revealed ? Icons.visibility_off : Icons.lightbulb_outline),
          label: Text(def.revealLabel(revealed: revealed)),
        ),
      if (active.contains(GameIntent.tally))
        FilledButton.tonalIcon(
          onPressed: () => onIntent(GameIntent.tally),
          icon: const Icon(Icons.add),
          label: const Text('+1'),
        ),
      if (active.contains(GameIntent.next))
        FilledButton.icon(
          onPressed: () => onIntent(GameIntent.next),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next'),
        ),
      if (active.contains(GameIntent.reset))
        FilledButton.icon(
          onPressed: () => onIntent(GameIntent.reset),
          icon: const Icon(Icons.replay),
          label: const Text('Again'),
        ),
    ];

    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (wire['n'] != null)
                Text(
                  done ? 'Done' : '${index + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const Spacer(),
              for (final b in buttons) ...[b, const SizedBox(width: 8)],
            ],
          ),
        ),
      ),
    );
  }
}

class _ControllerHeader extends StatelessWidget {
  const _ControllerHeader({required this.status, required this.onLeave});

  final LiveStatus status;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          _StatusPill(status: status),
          const Spacer(),
          TextButton.icon(
            onPressed: onLeave,
            icon: const Icon(Icons.close, color: Colors.white70),
            label: const Text('Leave', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _LobbyCard extends StatelessWidget {
  const _LobbyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, color: Colors.tealAccent, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinCard extends StatefulWidget {
  const _JoinCard({required this.controller, required this.onJoin});

  final TextEditingController controller;
  final ValueChanged<String> onJoin;

  @override
  State<_JoinCard> createState() => _JoinCardState();
}

class _JoinCardState extends State<_JoinCard> {
  void _submit() {
    final code = widget.controller.text.trim().toUpperCase();
    if (code.length >= 3) widget.onJoin(code);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.smartphone, color: Colors.tealAccent, size: 32),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Control a session',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'CODE',
                    hintStyle: TextStyle(
                      color: Colors.white24,
                      letterSpacing: 6,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(88, 56)),
                child: const Text('Join'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresenterHeader extends StatelessWidget {
  const _PresenterHeader({
    required this.code,
    required this.peers,
    required this.status,
    required this.onEnd,
  });

  final String code;
  final int peers;
  final LiveStatus status;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          const Text(
            'JOIN CODE  ',
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
              color: Colors.tealAccent,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          _StatusPill(status: status),
          const SizedBox(width: 10),
          const Icon(Icons.people_alt_outlined, color: Colors.white54, size: 18),
          const SizedBox(width: 4),
          Text('$peers', style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'End session',
            onPressed: onEnd,
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final LiveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LiveStatus.live => ('Live', Colors.greenAccent),
      LiveStatus.connecting => ('Connecting…', Colors.amberAccent),
      LiveStatus.error => ('Offline', Colors.redAccent),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
