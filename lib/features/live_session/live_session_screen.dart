import 'dart:async';
import 'dart:math';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/games/games/this_or_that_game.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/live/this-or-that` — the present/control flow over Realtime, now driven
/// by the unified Game framework (docs/GAMES.md Wave 0c). The SAME
/// `ThisOrThatGame` reducer + stage as the single-device
/// `/activity/this-or-that` runs here over a [LiveGameController] — one
/// source of truth for the game's logic and visuals. Only the lobby / join
/// code / presence chrome is live-specific and lives here.
///
/// Pick a role: **Present here** (the big screen — a join code + the slides)
/// or **Control** (the phone — a remote that drives the presenter).
class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({super.key});

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

enum _Mode { lobby, present, control }

/// 4 chars, no ambiguous glyphs (0/O/1/I/L) — easy to read off a screen.
String generateSessionCode() {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = Random();
  return List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  static const _def = ThisOrThatGame();

  _Mode _mode = _Mode.lobby;
  LiveGameController? _controller;
  final _subs = <StreamSubscription<dynamic>>[];
  final _codeCtrl = TextEditingController();

  Map<String, dynamic> _wire = const {};
  int _peers = 0;
  LiveStatus _status = LiveStatus.connecting;

  ThisOrThatState get _state => _def.decode(_wire);

  void _open(SessionRole role, String code) {
    if (_controller != null) return; // re-entrancy: ignore a double-tap
    // Curated ∪ synced AI/crowd, falling back to curated-only — the same
    // source the single-device runner reads. The resolved pairs ride in the
    // session state (presenter authoritative), so the controller renders
    // them from the broadcast with no content-ordering assumption.
    final snapshot = ref.read(bankedContentProvider).value ?? curatedSeeds;
    final c = LiveGameController.open(
      client: ref.read(supabaseProvider),
      role: role,
      code: code,
      def: _def,
      content: LocalContentBank(snapshot),
    );
    // mounted-guard each listener: a broadcast event can already be in the
    // microtask queue when the sub is cancelled (cancel is unawaited).
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
            _Mode.present => _presentView(context),
            _Mode.control => _controlView(context),
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
                'This or That — Live',
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
                subtitle: 'This screen shows the slides + a join code.',
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

  // ── Presenter (the big screen) ───────────────────────────────────────────
  Widget _presentView(BuildContext context) {
    final c = _controller!;
    return Column(
      children: [
        _PresenterHeader(
          code: c.code,
          peers: _peers,
          status: _status,
          onEnd: _leave,
        ),
        Expanded(child: _def.buildStage(context, _state)),
        _LiveControlBar(
          wire: _wire,
          revealLabel: _def.revealLabel(revealed: _wire['r'] == true),
          onIntent: c.send,
        ),
      ],
    );
  }

  // ── Controller (the phone remote) ─────────────────────────────────────────
  Widget _controlView(BuildContext context) {
    final theme = Theme.of(context);
    final c = _controller!;
    final state = _state;
    final (a, b) = state.current;
    final synced = _wire['n'] != null; // false until the first broadcast lands
    final total = (_wire['n'] as num?)?.toInt() ?? state.pairs.length;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _StatusPill(status: _status),
              const Spacer(),
              TextButton.icon(
                onPressed: _leave,
                icon: const Icon(Icons.close, color: Colors.white70),
                label: const Text(
                  'Leave',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            !synced
                ? 'Waiting for the presenter…'
                : state.done
                ? 'Wrapped up 🎉'
                : 'Slide ${state.index + 1} of $total',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (synced && !state.done)
            Text(
              '$a   ·   $b',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (state.revealed && !state.done) ...[
            const SizedBox(height: 8),
            const Text(
              'Discussing "why?"',
              style: TextStyle(color: Colors.amberAccent),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 72,
            child: FilledButton.icon(
              onPressed: () => c.send(GameIntent.next),
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
                  onPressed: () => c.send(GameIntent.back),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => c.send(GameIntent.reveal),
                  icon: Icon(
                    state.revealed
                        ? Icons.visibility_off
                        : Icons.lightbulb_outline,
                  ),
                  label: Text(state.revealed ? 'Hide' : 'Discuss'),
                ),
              ),
            ],
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
                style: FilledButton.styleFrom(
                  minimumSize: const Size(88, 56),
                ),
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
          const Icon(
            Icons.people_alt_outlined,
            color: Colors.white54,
            size: 18,
          ),
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

/// The presenter's host control bar — dark-themed for the big screen, driven
/// by the same [GameIntent] vocabulary as everything else. Reads the
/// conventional wire keys (i/n/d/r) for progress + the done state.
class _LiveControlBar extends StatelessWidget {
  const _LiveControlBar({
    required this.wire,
    required this.revealLabel,
    required this.onIntent,
  });

  final Map<String, dynamic> wire;
  final String revealLabel;
  final void Function(GameIntent) onIntent;

  @override
  Widget build(BuildContext context) {
    final index = (wire['i'] as num?)?.toInt() ?? 0;
    final total = (wire['n'] as num?)?.toInt() ?? 1;
    final done = wire['d'] == true;
    final revealed = wire['r'] == true;
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              done ? 'Done' : '${index + 1} / $total',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (done)
              FilledButton.icon(
                onPressed: () => onIntent(GameIntent.reset),
                icon: const Icon(Icons.replay),
                label: const Text('Again'),
              )
            else ...[
              IconButton.filledTonal(
                onPressed: index == 0 ? null : () => onIntent(GameIntent.back),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => onIntent(GameIntent.reveal),
                icon: Icon(
                  revealed ? Icons.visibility_off : Icons.lightbulb_outline,
                ),
                label: Text(revealLabel),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => onIntent(GameIntent.next),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
