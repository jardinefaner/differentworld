import 'dart:async';
import 'dart:math';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/live/this-or-that` — the end-to-end present/control flow for This-or-That
/// (docs/LIVE_SESSIONS.md). Pick a role: **Present here** (the big screen —
/// shows a join code + the slides) or **Control** (the phone — a remote that
/// drives the presenter over Realtime). Same content as the single-device
/// game, so a laptop presents while a phone advances.
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
  static const _palette = <(Color, Color)>[
    (Color(0xFFEF5350), Color(0xFF42A5F5)),
    (Color(0xFFFFA726), Color(0xFF26A69A)),
    (Color(0xFFAB47BC), Color(0xFF66BB6A)),
    (Color(0xFF5C6BC0), Color(0xFFFFCA28)),
    (Color(0xFFEC407A), Color(0xFF29B6F6)),
  ];

  late final List<ContentItem> _pairs = LocalContentBank.seeded().take(
    ContentKind.thisOrThat,
    8,
  );

  _Mode _mode = _Mode.lobby;
  LiveSession? _session;
  final _subs = <StreamSubscription<dynamic>>[];
  final _codeCtrl = TextEditingController();

  LiveState _live = const LiveState();
  int _peers = 0;
  LiveStatus _status = LiveStatus.connecting;

  int get _total => _pairs.length;

  void _open(SessionRole role, String code) {
    final s = LiveSession.open(
      client: ref.read(supabaseProvider),
      role: role,
      code: code,
      initialState: const LiveState().toMap(),
      reduce: LiveState.reducer(_total),
    );
    _subs
      ..add(
        s.states.listen((v) => setState(() => _live = LiveState.fromMap(v))),
      )
      ..add(s.peers.listen((v) => setState(() => _peers = v)))
      ..add(s.status.listen((v) => setState(() => _status = v)));
    setState(() {
      _session = s;
      _mode = role == SessionRole.present ? _Mode.present : _Mode.control;
    });
  }

  Future<void> _leave() async {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    await _session?.dispose();
    if (!mounted) return;
    setState(() {
      _session = null;
      _mode = _Mode.lobby;
      _live = const LiveState();
      _peers = 0;
      _status = LiveStatus.connecting;
    });
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_session?.dispose());
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
    return Column(
      children: [
        _PresenterHeader(
          code: _session?.code ?? '',
          peers: _peers,
          status: _status,
          onEnd: _leave,
        ),
        Expanded(
          child: _Presentation(
            pair: _pairs[_live.index],
            state: _live,
            palette: _palette[_live.index % _palette.length],
          ),
        ),
        _ControlBar(
          state: _live,
          total: _total,
          onBack: () => _session?.applyLocal('back'),
          onReveal: () => _session?.applyLocal('reveal'),
          onNext: () => _session?.applyLocal('next'),
          onRestart: () => _session?.applyLocal('restart'),
        ),
      ],
    );
  }

  // ── Controller (the phone remote) ─────────────────────────────────────────
  Widget _controlView(BuildContext context) {
    final theme = Theme.of(context);
    final a = _pairs[_live.index].payload['a']! as String;
    final b = _pairs[_live.index].payload['b']! as String;
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
            _live.done
                ? 'Wrapped up 🎉'
                : 'Slide ${_live.index + 1} of $_total',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (!_live.done)
            Text(
              '$a   ·   $b',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (_live.revealed && !_live.done) ...[
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
              onPressed: () => _session?.sendIntent('next'),
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
                  onPressed: () => _session?.sendIntent('back'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _session?.sendIntent('reveal'),
                  icon: Icon(
                    _live.revealed
                        ? Icons.visibility_off
                        : Icons.lightbulb_outline,
                  ),
                  label: Text(_live.revealed ? 'Hide' : 'Discuss'),
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

class _Presentation extends StatelessWidget {
  const _Presentation({
    required this.pair,
    required this.state,
    required this.palette,
  });

  final ContentItem pair;
  final LiveState state;
  final (Color, Color) palette;

  @override
  Widget build(BuildContext context) {
    if (state.done) {
      return const ColoredBox(
        color: Color(0xFF1B1B2F),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎉', style: TextStyle(fontSize: 64)),
              SizedBox(height: 12),
              Text(
                "That's a wrap!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final a = pair.payload['a']! as String;
    final b = pair.payload['b']! as String;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              child: _Half(text: a, color: palette.$1),
            ),
            Expanded(
              child: _Half(text: b, color: palette.$2),
            ),
          ],
        ),
        const Center(child: _OrBadge()),
        if (state.revealed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              child: const Text(
                'Why? Turn to a partner and tell them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.28)!],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FittedBox(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrBadge extends StatelessWidget {
  const _OrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'OR',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.state,
    required this.total,
    required this.onBack,
    required this.onReveal,
    required this.onNext,
    required this.onRestart,
  });

  final LiveState state;
  final int total;
  final VoidCallback onBack;
  final VoidCallback onReveal;
  final VoidCallback onNext;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              state.done ? 'Done' : '${state.index + 1} / $total',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (state.done)
              FilledButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.replay),
                label: const Text('Again'),
              )
            else ...[
              IconButton.filledTonal(
                onPressed: state.index == 0 ? null : onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onReveal,
                icon: Icon(
                  state.revealed
                      ? Icons.visibility_off
                      : Icons.lightbulb_outline,
                ),
                label: Text(state.revealed ? 'Hide' : 'Discuss'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onNext,
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
