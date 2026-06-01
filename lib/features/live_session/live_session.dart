import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The live-session layer (docs/LIVE_SESSIONS.md): a phone *controls* a game
/// running on a separate *presenter* screen (desktop / projector / web),
/// over Supabase **Realtime** broadcast — NOT PowerSync. This is ephemeral
/// coordination, not durable child data, so it rides a separate channel
/// (the same kind of documented Supabase-direct exception as auth/storage).
///
/// Protocol on channel `dw-session-<CODE>`:
///   - controller → broadcast `intent` `{intent: next|back|reveal|restart|hello}`
///   - presenter is AUTHORITATIVE: applies the reducer, then broadcasts the
///     canonical `state` `{i,r,d}` to everyone (also on every presence join,
///     so late controllers sync).
///   - controller ← `state` updates its mirror.

enum SessionRole { present, control }

enum LiveStatus { connecting, live, error }

/// The host-present game state (This-or-That shape): which slide, whether the
/// "why?" prompt is revealed, and whether the round is done.
class LiveState {
  const LiveState({this.index = 0, this.revealed = false, this.done = false});

  factory LiveState.fromMap(Map<String, dynamic> m) => LiveState(
    index: (m['i'] as num?)?.toInt() ?? 0,
    revealed: m['r'] == true,
    done: m['d'] == true,
  );

  final int index;
  final bool revealed;
  final bool done;

  LiveState copyWith({int? index, bool? revealed, bool? done}) => LiveState(
    index: index ?? this.index,
    revealed: revealed ?? this.revealed,
    done: done ?? this.done,
  );

  Map<String, dynamic> toMap() => {'i': index, 'r': revealed, 'd': done};

  /// Pure reducer — the presenter applies this to a controller's intent.
  /// Mirrors the single-device This-or-That control logic exactly. (A
  /// transform, not a constructor — it takes a state in.)
  // ignore: prefer_constructors_over_static_methods
  static LiveState reduce(LiveState s, String intent, int total) {
    switch (intent) {
      case 'next':
        if (s.done) return s;
        if (s.index >= total - 1) return s.copyWith(done: true);
        return s.copyWith(index: s.index + 1, revealed: false);
      case 'back':
        if (s.done) return s.copyWith(done: false);
        if (s.index == 0) return s;
        return s.copyWith(index: s.index - 1, revealed: false);
      case 'reveal':
        return s.copyWith(revealed: !s.revealed);
      case 'restart':
        return const LiveState();
      default:
        return s; // 'hello' / unknown — no-op (just triggers a rebroadcast)
    }
  }
}

/// A live present/control session over one Realtime channel.
class LiveSession {
  LiveSession._(this._channel, this.role, this.code, this._total);

  /// Open the channel for [role]. Returns immediately; [states] / [peers] /
  /// [status] emit as the connection comes up.
  factory LiveSession.open({
    required SupabaseClient client,
    required SessionRole role,
    required String code,
    required int total,
  }) {
    final channel = client.channel(topicFor(code));
    return LiveSession._(channel, role, code, total).._wire();
  }

  final RealtimeChannel _channel;
  final SessionRole role;
  final String code;
  final int _total;

  LiveState _state = const LiveState();
  LiveState get state => _state;

  final _states = StreamController<LiveState>.broadcast();
  Stream<LiveState> get states => _states.stream;

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
            _state = LiveState.reduce(_state, intent, _total);
            _emit();
            unawaited(_broadcastState());
          },
        )
        .onBroadcast(
          event: 'state',
          callback: (payload) {
            if (role != SessionRole.control) return;
            _state = LiveState.fromMap(payload);
            _emit();
          },
        )
        .onPresenceSync((_) {
          _peers.add(_channel.presenceState().length);
          // A device just (re)joined — presenter re-publishes so a late
          // controller mirrors the current slide.
          if (role == SessionRole.present) unawaited(_broadcastState());
        })
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _status.add(LiveStatus.live);
            unawaited(_channel.track({'role': role.name}));
            if (role == SessionRole.present) {
              unawaited(_broadcastState());
            } else {
              // ask the presenter to send current state
              unawaited(_send('intent', {'intent': 'hello'}));
            }
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            _status.add(LiveStatus.error);
          }
        });
    _status.add(LiveStatus.connecting);
  }

  void _emit() {
    if (!_states.isClosed) _states.add(_state);
  }

  Future<void> _send(String event, Map<String, dynamic> payload) async {
    try {
      await _channel.sendBroadcastMessage(event: event, payload: payload);
    } on Object catch (_) {
      // Best-effort coordination; a dropped frame self-heals on the next
      // intent / presence sync (the presenter rebroadcasts canonical state).
    }
  }

  Future<void> _broadcastState() => _send('state', _state.toMap());

  /// Controller → send an intent to the presenter.
  void sendIntent(String intent) {
    if (role == SessionRole.control) {
      unawaited(_send('intent', {'intent': intent}));
    }
  }

  /// Presenter → apply an intent locally (the host screen's own controls),
  /// reduce + rebroadcast, exactly as if a controller had sent it.
  void applyLocal(String intent) {
    if (role != SessionRole.present) return;
    _state = LiveState.reduce(_state, intent, _total);
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
