import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The **cast** layer (docs/LIVE_SESSIONS.md "the cast model"): an app-level
/// remote on top of [LiveSession]. The big screen is a clean **Receiver** (a
/// follower that only renders); the phone is the **Caster** (the authority —
/// picks what to present, drives it, switches it). The screen never shows the
/// launcher or the controls — *separation of concern*.
///
/// Built on the existing transport with NO new [SessionRole]: the Caster opens
/// as `present` (authority — holds + reduces + re-seeds), the Receiver as
/// `control` (a pure follower; the `role != present` guard in LiveSession's
/// `_wire` keeps it from ever applying the reducer).
///
/// The wire-state is a presentable wrapper — `{'game': id-or-null, 'state':
/// game-wire}` — so the Caster can switch WHICH game is live, not just
/// advance within one. Each game's own `GameDefinition` does the rest.
class CastSession {
  CastSession._(this._session);

  /// The screen. A pure follower: it subscribes, shows the code while idle,
  /// renders broadcasts, and never sends a thing.
  factory CastSession.receive({
    required SupabaseClient client,
    required String spaceId,
    required String code,
  }) {
    return CastSession._(
      LiveSession.open(
        client: client,
        role: SessionRole.control,
        code: code,
        topic: topicFor(spaceId, code),
        initialState: idleState,
        reduce: _noop,
      ),
    );
  }

  /// The phone cockpit. The authority: holds the meta-state, runs the
  /// meta-reducer on control taps, re-seeds on a cast.
  ///
  /// One authority per code. If two phones open the cockpit on the SAME code
  /// they both become `present` and broadcast competing state, so the screen
  /// flickers between them — there's no server-enforced admission control yet
  /// (see docs/LIVE_SESSIONS.md "Auth on the channel"). The 6-char code + exact
  /// match in the lobby make an accidental collision unlikely; a deliberate
  /// hand-off (one phone takes over) is a later feature.
  factory CastSession.cast({
    required SupabaseClient client,
    required String spaceId,
    required String code,
  }) {
    return CastSession._(
      LiveSession.open(
        client: client,
        role: SessionRole.present,
        code: code,
        topic: topicFor(spaceId, code),
        initialState: idleState,
        reduce: _metaReduce,
      ),
    );
  }

  /// Cast's OWN channel namespace, SPACE-SCOPED: a guessed code alone can't
  /// join — you also need the program's space id, an unguessable uuid that
  /// only program members hold (it's never shown in the UI). That possession
  /// IS the gate until true Realtime RLS auth lands — which is blocked today by
  /// the same ES256 `auth.uid()`-null issue that relaxed our REST write
  /// policies (see CLAUDE.md + docs/LIVE_SESSIONS.md "Auth on the channel").
  /// Kept distinct from `/live`'s `dw-session-<CODE>` so a code can't cross-wire
  /// the two flows. Caster + receiver each derive this from THEIR OWN
  /// `viewer.spaceId`, so two devices in the same program match; cross-program
  /// (or a not-signed-in device with no space) never collide.
  static String topicFor(String spaceId, String code) =>
      'dw-cast-$spaceId-${code.toUpperCase()}';

  final LiveSession _session;

  /// Nothing cast yet — the Receiver shows its "waiting for the phone" card.
  static Map<String, dynamic> get idleState => <String, dynamic>{'game': null};

  String get code => _session.code;
  Map<String, dynamic> get state => _session.state;
  Stream<Map<String, dynamic>> get states => _session.states;
  Stream<int> get peers => _session.peers;
  Stream<LiveStatus> get status => _session.status;

  /// The game currently cast (null = idle), parsed from any meta-state.
  static String? gameIdOf(Map<String, dynamic> meta) => meta['game'] as String?;

  /// The current game's wire-state (the inner `'state'`), for decode/buildStage.
  static Map<String, dynamic> gameStateOf(Map<String, dynamic> meta) =>
      (meta['state'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  // ── Caster-only verbs ────────────────────────────────────────────────────

  /// Put a game on the screen (or swap to a different one). Content-seeded
  /// here — OFF the pure reducer — because `initialState` is the one place a
  /// game reads content. Re-casting the same game = "play again" with fresh
  /// content.
  void cast(GameDefinition<dynamic> def, ContentSource content) {
    _session.reseed(_wire(def.id, def.initialState(content)));
  }

  /// Put a stage on the screen from an EXPLICIT, pre-built wire-state —
  /// for presentables that don't seed from the content bank (the world
  /// slideshow). The caller builds the self-describing state; the game's
  /// pure reducer drives it from there, same as any cast game.
  void castStage(String gameId, Map<String, dynamic> state) {
    _session.reseed(_wire(gameId, state));
  }

  /// The wire: the game id and its state as before, PLUS the stage described
  /// in shapes when the game can describe itself (stage_shape.dart).
  ///
  /// Both ride together on purpose. A receiver that knows the shape draws it
  /// generically — including for a game shipped after that receiver was
  /// built — and one that doesn't ignores the extra key and resolves the id
  /// exactly as it always has. Nothing has to be migrated in lockstep.
  static Map<String, dynamic> _wire(String id, Map<String, dynamic> state) {
    final def = gameById(id);
    final shape = def?.asShape(def.decode(state));
    return <String, dynamic>{
      'game': id,
      'state': state,
      if (shape != null) 'shape': shape.toWire(),
    };
  }

  /// The described stage on the wire, or null when this game doesn't describe
  /// itself (or the phone predates shapes).
  static StageShape? shapeOf(Map<String, dynamic> meta) =>
      StageShape.fromWire((meta['shape'] as Map?)?.cast<String, dynamic>());

  /// Clear the screen back to the idle "waiting" card.
  void clearStage() => _session.reseed(idleState);

  /// A control tap (Back/Reveal/Next/…). The authority reduces + rebroadcasts.
  void send(GameIntent intent, [Map<String, dynamic> args = const {}]) {
    _session.applyLocal(intent.name, args);
  }

  Future<void> dispose() => _session.dispose();

  // ── reducers ─────────────────────────────────────────────────────────────

  /// Receiver reducer — never runs (the `control` role doesn't reduce), but
  /// LiveSession requires one.
  static Map<String, dynamic> _noop(
    Map<String, dynamic> state,
    String intent,
    Map<String, dynamic> args,
  ) => state;

  /// Caster meta-reducer: delegate a game intent to the *currently cast*
  /// game's pure reducer, operating on the inner `'state'`. `cast` itself is
  /// NOT an intent (it needs content) — it goes through [cast]→`reseed`. The
  /// session's internal `hello` sync ping (and any unknown intent) is a no-op
  /// that just triggers a canonical rebroadcast.
  static Map<String, dynamic> _metaReduce(
    Map<String, dynamic> state,
    String intent,
    Map<String, dynamic> args,
  ) {
    final id = state['game'] as String?;
    if (id == null) return state;
    final def = gameById(id);
    if (def == null) return state;
    final mapped = _intentByName(intent);
    if (mapped == null) return state;
    final gameWire =
        (state['state'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    // Re-describe after every intent — the shape IS the state, so a stale
    // shape would show the room the previous move.
    return _wire(id, def.reduce(gameWire, mapped, args));
  }

  static GameIntent? _intentByName(String name) {
    for (final i in GameIntent.values) {
      if (i.name == name) return i;
    }
    return null;
  }
}
