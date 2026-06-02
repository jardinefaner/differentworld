import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/live_session/charades.dart';
import 'package:differentworld/features/live_session/live_game_screen.dart'
    show generateSessionCode;
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/live/charades` — the two-device (three, really) showcase
/// (docs/GAMES.md): the **actor's phone** shows the secret word, the **room**
/// watches a big screen that shows only the category, and the **teacher's
/// phone** marks Got it / Skip. All on the generic [LiveSession] seam.
class CharadesLiveScreen extends ConsumerStatefulWidget {
  const CharadesLiveScreen({super.key});

  @override
  ConsumerState<CharadesLiveScreen> createState() => _CharadesLiveScreenState();
}

enum _Mode { lobby, present, act, control }

class _CharadesLiveScreenState extends ConsumerState<CharadesLiveScreen> {
  // Stable order (NOT shuffled) so every device maps index → same word.
  late final List<ContentItem> _prompts = LocalContentBank.seeded().take(
    ContentKind.charades,
    16,
  );

  _Mode _mode = _Mode.lobby;
  LiveSession? _session;
  final _subs = <StreamSubscription<dynamic>>[];
  final _codeCtrl = TextEditingController();

  CharadesState _state = const CharadesState();
  int _peers = 0;
  LiveStatus _status = LiveStatus.connecting;

  int get _total => _prompts.length;
  String _word(int i) => _prompts[i].payload['word']! as String;
  String _category(int i) => _prompts[i].payload['category']! as String;

  void _open(SessionRole role, String code, _Mode mode) {
    final s = LiveSession.open(
      client: ref.read(supabaseProvider),
      role: role,
      code: code,
      initialState: const CharadesState().toMap(),
      reduce: CharadesState.reducer(_total),
    );
    _subs
      ..add(
        s.states.listen(
          (v) => setState(() => _state = CharadesState.fromMap(v)),
        ),
      )
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
      _state = const CharadesState();
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
        color: const Color(0xFF15101F),
        child: SafeArea(
          child: switch (_mode) {
            _Mode.lobby => _lobby(context),
            _Mode.present => _presentView(context),
            _Mode.act => _actView(context),
            _Mode.control => _controlView(context),
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
                'Charades — Live',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The room watches the big screen (just a category). The '
                "actor's phone shows the secret word.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 24),
              _LobbyCard(
                icon: Icons.cast,
                title: 'Present here',
                subtitle: 'The room screen — category + score, never the word.',
                onTap: () => _open(
                  SessionRole.present,
                  generateSessionCode(),
                  _Mode.present,
                ),
              ),
              const SizedBox(height: 14),
              _JoinCard(
                controller: _codeCtrl,
                onActor: (code) => _open(SessionRole.secret, code, _Mode.act),
                onController: (code) =>
                    _open(SessionRole.control, code, _Mode.control),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The big screen the ROOM watches — category + score, never the word.
  Widget _presentView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _Header(
          code: _session?.code ?? '',
          peers: _peers,
          status: _status,
          onEnd: _leave,
        ),
        Expanded(
          child: Center(
            child: _state.done
                ? _wrap(context)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ACT IT OUT — NO WORDS!',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _category(_state.index),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${_state.found} guessed',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        // Standalone fallback controls (no word shown) so a single laptop
        // can run it; usually the teacher's phone drives instead.
        _PresentBar(
          done: _state.done,
          onGot: () => _session?.applyLocal('got'),
          onSkip: () => _session?.applyLocal('skip'),
          onRestart: () => _session?.applyLocal('restart'),
        ),
      ],
    );
  }

  // The ACTOR's phone — the secret word, for their eyes only.
  Widget _actView(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
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
          const Spacer(),
          if (_state.done)
            _wrap(context)
          else ...[
            const Text(
              'ACT THIS OUT — NO TALKING!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _word(_state.index),
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "(${_category(_state.index)} · the room can't see this)",
              style: const TextStyle(color: Colors.white38),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  // The TEACHER's phone — sees the word, marks the room's guess.
  Widget _controlView(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              _StatusDot(status: _status),
              const SizedBox(width: 8),
              Text(
                '${_state.found} guessed',
                style: const TextStyle(color: Colors.white70),
              ),
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
          const Spacer(),
          if (_state.done) ...[
            _wrap(context),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: () => _session?.sendIntent('restart'),
              child: const Text('Play again'),
            ),
          ] else ...[
            Text(
              'The word is',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _word(_state.index),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _category(_state.index),
              style: const TextStyle(color: Colors.purpleAccent),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton.icon(
                onPressed: () => _session?.sendIntent('got'),
                icon: const Icon(Icons.check, size: 28),
                label: const Text(
                  'Got it!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _session?.sendIntent('skip'),
                icon: const Icon(Icons.skip_next),
                label: const Text('Skip this one'),
              ),
            ),
          ],
          if (!_state.done) const Spacer(),
        ],
      ),
    );
  }

  Widget _wrap(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎭', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(
          'Great round!',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_state.found} guessed, together.',
          style: const TextStyle(color: Colors.white60),
        ),
      ],
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
              Icon(icon, color: Colors.purpleAccent, size: 32),
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
  const _JoinCard({
    required this.controller,
    required this.onActor,
    required this.onController,
  });

  final TextEditingController controller;
  final ValueChanged<String> onActor;
  final ValueChanged<String> onController;

  String? _code() {
    final c = controller.text.trim().toUpperCase();
    return c.length >= 3 ? c : null;
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
            'Join a session',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 6,
              fontWeight: FontWeight.w800,
            ),
            decoration: const InputDecoration(
              hintText: 'CODE',
              hintStyle: TextStyle(color: Colors.white24, letterSpacing: 6),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final c = _code();
                    if (c != null) onActor(c);
                  },
                  icon: const Icon(Icons.theater_comedy),
                  label: const Text("I'm acting"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final c = _code();
                    if (c != null) onController(c);
                  },
                  icon: const Icon(Icons.sports_esports),
                  label: const Text('Control'),
                ),
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
              color: Colors.purpleAccent,
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
            tooltip: 'End session',
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

class _PresentBar extends StatelessWidget {
  const _PresentBar({
    required this.done,
    required this.onGot,
    required this.onSkip,
    required this.onRestart,
  });

  final bool done;
  final VoidCallback onGot;
  final VoidCallback onSkip;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Text(
              'Drive from a phone, or here:',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const Spacer(),
            if (done)
              FilledButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.replay),
                label: const Text('Again'),
              )
            else ...[
              OutlinedButton(onPressed: onSkip, child: const Text('Skip')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onGot,
                icon: const Icon(Icons.check),
                label: const Text('Got it'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
