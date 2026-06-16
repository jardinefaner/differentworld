import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/live_session/cast_session.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The live cast, as a snapshot for the UI. Distinct from the [CastSession]
/// itself so the chrome can render "Casting · CODE" reactively without owning
/// the session.
class CastSnapshot {
  const CastSnapshot({
    this.session,
    this.meta = const {'game': null},
    this.status = LiveStatus.connecting,
    this.peers = 0,
  });

  final CastSession? session;
  final Map<String, dynamic> meta;
  final LiveStatus status;
  final int peers;

  /// A session is live the moment it's been started — the anchor shows even
  /// while connecting, so the join code is visible immediately.
  bool get active => session != null;
  String? get code => session?.code;

  /// The id of the game/stage currently on the screen (null = idle "waiting").
  String? get castingGameId =>
      session == null ? null : CastSession.gameIdOf(meta);

  CastSnapshot _with({
    Map<String, dynamic>? meta,
    LiveStatus? status,
    int? peers,
  }) =>
      CastSnapshot(
        session: session,
        meta: meta ?? this.meta,
        status: status ?? this.status,
        peers: peers ?? this.peers,
      );
}

/// Owns the **Caster** session ABOVE the screen, so casting persists across
/// navigation (docs/LIVE_SESSIONS.md — "the anchor"). The `/cast` cockpit
/// drives it and the top-chrome cast pill renders it on every screen; leaving
/// either does NOT end the cast — only [stop] does. KeepAlive by default
/// (a plain NotifierProvider), so the session survives route changes.
class CastSessionController extends Notifier<CastSnapshot> {
  final _subs = <StreamSubscription<dynamic>>[];
  // The owned session as a plain field. _teardown disposes THIS, never
  // `state` — reading a provider's state inside an onDispose lifecycle is
  // forbidden by Riverpod ("Cannot use Ref ... inside life-cycles").
  CastSession? _live;

  @override
  CastSnapshot build() {
    ref.onDispose(_teardown);
    return const CastSnapshot();
  }

  /// Become the authority on [code] (idempotent — already casting that code is
  /// a no-op, so re-opening the cockpit reuses the live session). Any prior
  /// session on a different code is torn down first.
  void start(String code) {
    if (_live?.code == code) return;
    _teardown();
    final session = CastSession.cast(
      client: ref.read(supabaseProvider),
      code: code,
    );
    _live = session;
    _subs
      ..add(session.states.listen((m) => state = state._with(meta: m)))
      ..add(session.status.listen((s) => state = state._with(status: s)))
      ..add(session.peers.listen((p) => state = state._with(peers: p)));
    state = CastSnapshot(session: session);
  }

  /// End the cast entirely (disposes the session, clears the anchor).
  void stop() {
    _teardown();
    state = const CastSnapshot();
  }

  // ── drive verbs (delegate to the live session) ──────────────────────────
  void castGame(GameDefinition<dynamic> def, ContentSource content) =>
      state.session?.cast(def, content);
  void castStage(String gameId, Map<String, dynamic> wire) =>
      state.session?.castStage(gameId, wire);
  void clearStage() => state.session?.clearStage();
  void send(GameIntent intent, [Map<String, dynamic> args = const {}]) =>
      state.session?.send(intent, args);

  void _teardown() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    unawaited(_live?.dispose());
    _live = null;
  }
}

final castSessionProvider =
    NotifierProvider<CastSessionController, CastSnapshot>(
  CastSessionController.new,
);
