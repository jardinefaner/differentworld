import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The live-session layer (docs/LIVE_SESSIONS.md): a phone *controls* a game
/// running on a separate *presenter* screen (desktop / projector / web),
/// over Supabase **Realtime** broadcast — NOT PowerSync. Ephemeral
/// coordination, not durable child data (the documented Supabase-direct
/// exception in CLAUDE.md). No row is read or written here; nothing persists.
///
/// Game-AGNOSTIC: the session carries an opaque `Map<String,dynamic>` state
/// and a [LiveReducer]. Each game defines its own state shape + rules
/// (This-or-That via this_or_that_game.dart's GameDefinition; Charades via
/// charades.dart). Build the seam once → the whole deck goes present/control.
///
/// Protocol on channel `dw-session-<CODE>`:
///   - controller → broadcast `intent` `{intent, args}`
///   - presenter is AUTHORITATIVE: applies the reducer, then broadcasts the
///     canonical `state` to everyone (also on every presence join, so late
///     joiners sync).
///   - control + secret roles ← `state` updates their mirror.

/// present = the big screen (authoritative). control = a phone remote.
/// secret = a phone that mirrors state but never drives (e.g. the Charades
/// actor, whose screen shows the word the room can't see).
enum SessionRole { present, control, secret }

enum LiveStatus { connecting, live, error }

/// The presenter applies this to a controller intent. Pure.
typedef LiveReducer =
    Map<String, dynamic> Function(
      Map<String, dynamic> state,
      String intent,
      Map<String, dynamic> args,
    );

/// A live present/control session over one Realtime channel.
class LiveSession {
  LiveSession._(this._channel, this.role, this.code, this._reduce, this._state);

  /// Open the channel for [role]. Returns immediately; [states] / [peers] /
  /// [status] emit as the connection comes up.
  factory LiveSession.open({
    required SupabaseClient client,
    required SessionRole role,
    required String code,
    required Map<String, dynamic> initialState,
    required LiveReducer reduce,
    String? topic,
  }) {
    // [topic] lets a caller use a SEPARATE channel namespace for the same
    // join code — the cast layer passes `dw-cast-<CODE>` so a cast session
    // can't collide with a `/live` per-game session that happens to share a
    // code (which would feed the wrong-shaped state to the other's decoder).
    final channel = client.channel(topic ?? topicFor(code));
    return LiveSession._(
      channel,
      role,
      code,
      reduce,
      Map<String, dynamic>.of(initialState),
    ).._wire();
  }

  final RealtimeChannel _channel;
  final SessionRole role;
  final String code;
  final LiveReducer _reduce;
  Map<String, dynamic> _state;

  Map<String, dynamic> get state => _state;

  final _states = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get states => _states.stream;

  final _peers = StreamController<int>.broadcast();
  Stream<int> get peers => _peers.stream;

  final _status = StreamController<LiveStatus>.broadcast();
  Stream<LiveStatus> get status => _status.stream;

  static String topicFor(String code) => 'dw-session-${code.toUpperCase()}';

  void _wire() {
    _channel
        .onBroadcast(
          event: 'intent',
          callback: (payload) {
            if (role != SessionRole.present) return; // presenter is authority
            final intent = payload['intent'] as String? ?? '';
            final args =
                (payload['args'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
            _state = _reduce(_state, intent, args);
            _emit();
            unawaited(_broadcastState());
          },
        )
        .onBroadcast(
          event: 'state',
          callback: (payload) {
            if (role == SessionRole.present) return; // presenter owns it
            final s = (payload['state'] as Map?)?.cast<String, dynamic>();
            if (s != null) {
              _state = s;
              _emit();
            }
          },
        )
        .onPresenceSync((_) {
          _addPeers(_channel.presenceState().length);
          // A device just (re)joined — presenter re-publishes so it syncs.
          if (role == SessionRole.present) unawaited(_broadcastState());
        })
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _addStatus(LiveStatus.live);
            unawaited(_channel.track({'role': role.name}));
            if (role == SessionRole.present) {
              unawaited(_broadcastState());
            } else {
              // ask the presenter to send current state
              unawaited(_send('intent', {'intent': 'hello'}));
            }
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            _addStatus(LiveStatus.error);
          }
        });
    _addStatus(LiveStatus.connecting);
  }

  // Realtime callbacks can fire after dispose() closes the sinks (unsubscribe
  // is async + unawaited), so every add guards isClosed — not just _states.
  void _emit() {
    if (!_states.isClosed) _states.add(_state);
  }

  void _addPeers(int n) {
    if (!_peers.isClosed) _peers.add(n);
  }

  void _addStatus(LiveStatus s) {
    if (!_status.isClosed) _status.add(s);
  }

  Future<void> _send(String event, Map<String, dynamic> payload) async {
    try {
      await _channel.sendBroadcastMessage(event: event, payload: payload);
    } on Object catch (_) {
      // Best-effort coordination; a dropped frame self-heals on the next
      // intent / presence sync (the presenter rebroadcasts canonical state).
    }
  }

  Future<void> _broadcastState() => _send('state', {'state': _state});

  /// Controller → send an intent (with optional args) to the presenter.
  void sendIntent(String intent, [Map<String, dynamic> args = const {}]) {
    if (role == SessionRole.control) {
      unawaited(_send('intent', {'intent': intent, 'args': args}));
    }
  }

  /// Presenter → apply an intent locally (the host screen's own controls),
  /// reduce + rebroadcast, as if a controller had sent it.
  void applyLocal(String intent, [Map<String, dynamic> args = const {}]) {
    if (role != SessionRole.present) return;
    _state = _reduce(_state, intent, args);
    _emit();
    unawaited(_broadcastState());
  }

  /// Presenter → replace the canonical state with a freshly-seeded one
  /// ("play again with NEW content"). The reducer is pure (no content access),
  /// so a fresh round comes from re-running the game's `initialState`, not the
  /// reducer. Emits + rebroadcasts so every controller syncs the new round.
  void reseed(Map<String, dynamic> fresh) {
    if (role != SessionRole.present) return;
    _state = fresh;
    _emit();
    unawaited(_broadcastState());
  }

  Future<void> dispose() async {
    await _channel.unsubscribe();
    await _states.close();
    await _peers.close();
    await _status.close();
  }
}
