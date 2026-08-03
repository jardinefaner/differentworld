import 'dart:async';
import 'dart:math';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/activity_runtime/content_engine.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/games/game_fullscreen.dart';
import 'package:differentworld/features/live_session/cast_stage_chrome.dart';
import 'package:differentworld/features/live_session/live_lobby.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
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
  const LiveGameScreen({
    required this.def,
    this.seed,
    this.autoJoin,
    super.key,
  });

  final GameDefinition<S> def;

  /// Optional pre-built initial wire-state for data-driven presentables —
  /// the presenter seeds from Drift (roster/schedule); the controller gets it
  /// via the broadcast (self-describing state).
  final Map<String, dynamic>? seed;

  /// When set (the program-wide "join" path, docs/LIVE_SESSIONS.md), the
  /// screen skips its lobby and opens straight into the given role for the
  /// given code — the game was already resolved (via `gameById`) from the
  /// session the user tapped to join.
  final ({String code, SessionRole role})? autoJoin;

  @override
  ConsumerState<LiveGameScreen<S>> createState() => _LiveGameScreenState<S>();
}

enum _Mode { lobby, present, secret, control }

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
  // Presenter-only: announces this session to the program lobby so others can
  // discover + join it (docs/LIVE_SESSIONS.md). Null for controllers.
  LobbyAnnouncer? _announcer;
  // True between an autoJoin request and the controller actually opening, so
  // the screen shows a "Joining…" spinner instead of flashing the lobby.
  bool _autoJoining = false;
  final _subs = <StreamSubscription<dynamic>>[];
  final _codeCtrl = TextEditingController();

  Map<String, dynamic> _wire = const {};
  int _peers = 0;
  LiveStatus _status = LiveStatus.connecting;

  @override
  void initState() {
    super.initState();
    if (widget.autoJoin != null) {
      _autoJoining = true;
      // After first frame so _open's ref.read(...) calls are safe. Re-read
      // widget.autoJoin AT callback time (not a captured initState value) and
      // guard _controller, so a reused State / double post-frame can't open a
      // stale or second session.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final autoJoin = widget.autoJoin;
        if (mounted && autoJoin != null && _controller == null) {
          _open(autoJoin.role, autoJoin.code);
        }
      });
    }
  }

  void _open(SessionRole role, String code) {
    if (_controller != null) return; // re-entrancy: ignore a double-tap
    final snapshot = ref.read(bankedContentProvider).value ?? curatedSeeds;
    final c = LiveGameController.open(
      client: ref.read(supabaseProvider),
      role: role,
      code: code,
      def: _def,
      content: ContentEngine(snapshot),
      seed: widget.seed,
    );
    _subs
      ..add(
        c.states.listen((v) {
          if (mounted) setState(() => _wire = v);
        }),
      )
      ..add(
        c.peers.listen((v) {
          if (mounted) setState(() => _peers = v);
        }),
      )
      ..add(
        c.status.listen((v) {
          if (mounted) setState(() => _status = v);
        }),
      );
    setState(() {
      _controller = c;
      _wire = c.state;
      _autoJoining = false;
      _mode = switch (role) {
        SessionRole.present => _Mode.present,
        SessionRole.secret => _Mode.secret,
        SessionRole.control => _Mode.control,
      };
    });
    // The presenter announces to the program lobby so the room can find +
    // join from Today — without anyone navigating to this game's route first.
    if (role == SessionRole.present) {
      final viewer = ref.read(viewerProvider);
      final spaceId = viewer.spaceId;
      final memberId = viewer.memberId;
      if (spaceId != null && memberId != null) {
        _announcer = LobbyAnnouncer.announce(
          client: ref.read(supabaseProvider),
          spaceId: spaceId,
          memberId: memberId,
          code: code,
          game: _def.id,
          presenter: viewer.displayName,
        );
      }
    }
  }

  void _leave() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    _controller?.dispose();
    // Null both here; the disjoint dispose() path's `?.dispose()` is then a
    // safe no-op (LobbyAnnouncer.dispose is idempotent; the stream guards
    // check mounted/isClosed).
    _controller = null;
    unawaited(_announcer?.dispose());
    _announcer = null;
    if (!mounted) return;
    setState(() {
      _mode = _Mode.lobby;
      _wire = const {};
      _peers = 0;
      _status = LiveStatus.connecting;
      _autoJoining = false;
    });
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _controller?.dispose();
    unawaited(_announcer?.dispose());
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: const Color(0xFF11121A),
        child: SafeArea(
          child: (_autoJoining && _controller == null)
              ? const _Connecting()
              : switch (_mode) {
                  _Mode.lobby => _lobby(context),
                  _Mode.present => _stageView(context, isPresenter: true),
                  _Mode.secret => _secretView(context),
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
                onActor: _def.hasSecretRole
                    ? (code) => _open(SessionRole.secret, code)
                    : null,
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
    // The room (presenter) always shows the public stage; the controller of a
    // secret-role game (the teacher) sees the secret stage instead, so they
    // can mark the room's guess.
    final stage = isPresenter
        ? _def.buildStage(context, state)
        : (_def.buildSecretStage(context, state) ??
              _def.buildStage(context, state));
    return Column(
      children: [
        if (isPresenter)
          _PresenterHeader(
            code: c.code,
            peers: _peers,
            status: _status,
            onEnd: _leave,
            onFullscreen: () => unawaited(
              GameFullscreenScreen.open(
                context,
                def: _def,
                controller: c,
                joinCode: c.code,
              ),
            ),
          )
        else
          _ControllerHeader(status: _status, onLeave: _leave),
        Expanded(child: stage),
        if (custom != null)
          _CustomLiveBar(child: custom)
        else
          GameIntentBar(
            def: _def,
            wire: _wire,
            onIntent: c.send,
            withSafeArea: true,
          ),
      ],
    );
  }

  // ── Secret (actor) view — the secret stage only; the actor just watches
  // (e.g. Charades' word) and never drives. ────────────────────────────────
  Widget _secretView(BuildContext context) {
    final state = _def.decode(_wire);
    return Column(
      children: [
        _ControllerHeader(status: _status, onLeave: _leave),
        Expanded(
          child:
              _def.buildSecretStage(context, state) ??
              _def.buildStage(context, state),
        ),
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
  const _JoinCard({
    required this.controller,
    required this.onJoin,
    this.onActor,
  });

  final TextEditingController controller;
  final ValueChanged<String> onJoin;

  /// When non-null, the game has a secret/actor role — the card offers a
  /// second "I'm acting" button (joins as [SessionRole.secret]).
  final ValueChanged<String>? onActor;

  @override
  State<_JoinCard> createState() => _JoinCardState();
}

class _JoinCardState extends State<_JoinCard> {
  String? _code() {
    final code = widget.controller.text.trim().toUpperCase();
    // Codes are exactly 4 chars (generateSessionCode); requiring 4 stops a
    // short entry joining a channel with no presenter and hanging on
    // "Connecting…".
    return code.length >= 4 ? code : null;
  }

  void _submit() {
    final code = _code();
    if (code != null) widget.onJoin(code);
  }

  @override
  Widget build(BuildContext context) {
    final hasActor = widget.onActor != null;
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
                  'Join a session',
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
          TextField(
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
              hintStyle: TextStyle(color: Colors.white24, letterSpacing: 6),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (hasActor)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final code = _code();
                      if (code != null) widget.onActor!(code);
                    },
                    icon: const Icon(Icons.theater_comedy),
                    label: const Text("I'm acting"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.sports_esports),
                    label: const Text('Control'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(88, 56)),
                child: const Text('Join'),
              ),
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
    required this.onFullscreen,
  });

  final String code;
  final int peers;
  final LiveStatus status;
  final VoidCallback onEnd;
  final VoidCallback onFullscreen;

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
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Fullscreen',
            onPressed: onFullscreen,
            icon: const Icon(Icons.fullscreen, color: Colors.white54),
          ),
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

/// Shown for a `/join` link whose game this build can't resolve (a session
/// running a newer game) or a malformed link — instead of a blank screen.
class JoinUnavailableScreen extends StatelessWidget {
  const JoinUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EdgeScaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.link_off,
          title: "Can't join this session",
          message:
              'The link looks off, or this session is running a newer '
              'version of the app. Ask the presenter for the join code.',
        ),
      ),
    );
  }
}

/// The brief "Joining…" state shown while an auto-join (from the Today live
/// banner / a join link) connects, so the lobby never flashes.
class _Connecting extends StatelessWidget {
  const _Connecting();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.tealAccent),
          SizedBox(height: 16),
          Text(
            'Joining…',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
