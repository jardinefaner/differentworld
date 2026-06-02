import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/live_session/board_session.dart';
import 'package:differentworld/features/live_session/live_session.dart'
    show LiveStatus;
import 'package:differentworld/features/live_session/live_session_screen.dart'
    show generateSessionCode;
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/board` — the anonymous brainstorm / agenda board (docs/VISION.md #5).
/// Present a shared wall on the big screen; everyone posts ideas from their
/// phone with **no names attached**. Same Realtime rails as the live games,
/// a different shape (an append-only wall, not a controlled game).
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

enum _Mode { lobby, present, contribute }

class _BoardScreenState extends ConsumerState<BoardScreen> {
  _Mode _mode = _Mode.lobby;
  BoardSession? _session;
  final _subs = <StreamSubscription<dynamic>>[];
  final _codeCtrl = TextEditingController();
  final _ideaCtrl = TextEditingController();

  List<String> _ideas = const [];
  int _peers = 0;
  LiveStatus _status = LiveStatus.connecting;

  void _open(BoardRole role, String code, _Mode mode) {
    final s = BoardSession.open(
      client: ref.read(supabaseProvider),
      role: role,
      code: code,
    );
    _subs
      ..add(s.ideas.listen((v) => setState(() => _ideas = v)))
      ..add(s.peers.listen((v) => setState(() => _peers = v)))
      ..add(s.status.listen((v) => setState(() => _status = v)));
    setState(() {
      _session = s;
      _mode = mode;
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
      _ideas = const [];
      _peers = 0;
      _status = LiveStatus.connecting;
    });
  }

  void _post() {
    final t = _ideaCtrl.text.trim();
    if (t.isEmpty) return;
    _session?.post(t);
    _ideaCtrl.clear();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_session?.dispose());
    _codeCtrl.dispose();
    _ideaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: const Color(0xFF101418),
        child: SafeArea(
          child: switch (_mode) {
            _Mode.lobby => _lobby(context),
            _Mode.present => _presentView(context),
            _Mode.contribute => _contributeView(context),
          },
        ),
      ),
    );
  }

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
                'Brainstorm Board',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Everyone posts ideas from their phone — no names. Look at '
                'them together on the big screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 24),
              _LobbyCard(
                icon: Icons.tv,
                title: 'Present the board',
                subtitle: 'This screen shows the wall + a join code.',
                onTap: () => _open(
                  BoardRole.present,
                  generateSessionCode(),
                  _Mode.present,
                ),
              ),
              const SizedBox(height: 14),
              _JoinCard(
                controller: _codeCtrl,
                onJoin: (code) =>
                    _open(BoardRole.contribute, code, _Mode.contribute),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presentView(BuildContext context) {
    return Column(
      children: [
        _Header(
          code: _session?.code ?? '',
          peers: _peers,
          status: _status,
          onEnd: _leave,
        ),
        Expanded(
          child: _ideas.isEmpty
              ? const _EmptyWall()
              : _Wall(ideas: _ideas, big: true),
        ),
      ],
    );
  }

  Widget _contributeView(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              _StatusDot(status: _status),
              const Spacer(),
              TextButton(
                onPressed: _leave,
                child: const Text(
                  'Leave',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _ideas.isEmpty
              ? const _EmptyWall()
              : _Wall(ideas: _ideas, big: false),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ideaCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _post(),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add an idea (anonymous)…',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _post,
                style: FilledButton.styleFrom(minimumSize: const Size(72, 56)),
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Wall extends StatelessWidget {
  const _Wall({required this.ideas, required this.big});

  final List<String> ideas;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ideas.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(big ? 20 : 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            ideas[i],
            style: TextStyle(
              color: Colors.white,
              fontSize: big ? 24 : 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyWall extends StatelessWidget {
  const _EmptyWall();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Ideas will appear here',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No names — just the ideas.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
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
              Icon(icon, color: Colors.cyanAccent, size: 32),
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

class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.controller, required this.onJoin});

  final TextEditingController controller;
  final ValueChanged<String> onJoin;

  void _submit() {
    final code = controller.text.trim().toUpperCase();
    if (code.length >= 3) onJoin(code);
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
          const Text(
            'Join to add ideas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
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

class _Header extends StatelessWidget {
  const _Header({
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
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
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
              color: Colors.cyanAccent,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          _StatusDot(status: status),
          const SizedBox(width: 8),
          const Icon(
            Icons.people_alt_outlined,
            color: Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text('$peers', style: const TextStyle(color: Colors.white70)),
          IconButton(
            tooltip: 'End',
            onPressed: onEnd,
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

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
