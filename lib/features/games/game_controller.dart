import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What a control surface talks to — it does NOT know whether it's driving
/// a single device or a live session. Tap (the on-screen control bar),
/// keyboard (`PresenterShortcuts`), the teacher's phone remote, and a
/// contributor phone all call [send]; new state flows back on [states].
///
/// This is the seam that makes "one reducer, four control surfaces" real
/// (docs/GAMES.md, VISION #17): swap the implementation, keep the game.
abstract class GameController {
  /// The current wire-state.
  Map<String, dynamic> get state;

  /// Emits the wire-state after every applied intent.
  Stream<Map<String, dynamic>> get states;

  /// Send an intent. On a single device it reduces synchronously; on a
  /// live session a controller sends it to the presenter, who reduces.
  void send(GameIntent intent, [Map<String, dynamic> args = const {}]);

  /// Release resources (the state stream). Idempotent.
  void dispose();
}

/// Single device — the host-present, teacher-controls case (one laptop /
/// projector, or a phone). Holds the wire-state in memory and applies the
/// game's reducer synchronously. No setState of game logic anywhere; the
/// view is a pure function of [states].
class LocalGameController implements GameController {
  LocalGameController({
    required Map<String, dynamic> initial,
    required GameReducer reduce,
  }) : _state = initial,
       _reduce = reduce;

  final GameReducer _reduce;
  Map<String, dynamic> _state;
  final StreamController<Map<String, dynamic>> _states =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Map<String, dynamic> get state => _state;

  @override
  Stream<Map<String, dynamic>> get states => _states.stream;

  @override
  void send(GameIntent intent, [Map<String, dynamic> args = const {}]) {
    _state = _reduce(_state, intent, args);
    if (!_states.isClosed) _states.add(_state);
  }

  @override
  void dispose() {
    unawaited(_states.close());
  }
}

/// Live — the two-device case (docs/LIVE_SESSIONS.md). Wraps a [LiveSession]
/// over Supabase Realtime so the SAME game definition that runs on one
/// device runs across two: a presenter (the big screen, authoritative) and a
/// controller (the phone remote). The framework's [GameIntent] vocabulary is
/// bridged to the session's String-keyed protocol by name; the game's pure
/// `def.reduce` becomes the session's [LiveReducer] verbatim.
///
/// Beyond the [GameController] seam this exposes the live-only signals the
/// session chrome needs — [peers], [status], [code] — which the generic
/// `GameScaffold` ignores (they render in the live header, not the bar).
class LiveGameController implements GameController {
  LiveGameController._(this._session);

  /// Open a session for [role] and drive [def] over it. The presenter seeds
  /// the authoritative state from `def.initialState(content)` (self-
  /// describing — the resolved content rides in the state, so controllers
  /// render it from the broadcast with no content-ordering assumption).
  factory LiveGameController.open({
    required SupabaseClient client,
    required SessionRole role,
    required String code,
    required GameDefinition<dynamic> def,
    required ContentSource content,
    Map<String, dynamic>? seed,
  }) {
    final session = LiveSession.open(
      client: client,
      role: role,
      code: code,
      initialState: seed ?? def.initialState(content),
      reduce: _adapt(def),
    );
    return LiveGameController._(session);
  }

  final LiveSession _session;
  bool _disposed = false;

  SessionRole get role => _session.role;
  String get code => _session.code;
  Stream<int> get peers => _session.peers;
  Stream<LiveStatus> get status => _session.status;

  @override
  Map<String, dynamic> get state => _session.state;

  @override
  Stream<Map<String, dynamic>> get states => _session.states;

  @override
  void send(GameIntent intent, [Map<String, dynamic> args = const {}]) {
    // The presenter is authoritative (reduces locally + rebroadcasts); a
    // controller forwards the intent to the presenter. LiveSession itself
    // no-ops the wrong-role call, so this is just the intent.name bridge.
    if (_session.role == SessionRole.present) {
      _session.applyLocal(intent.name, args);
    } else {
      _session.sendIntent(intent.name, args);
    }
  }

  @override
  void dispose() {
    // Idempotent — LiveSession.dispose() closes its stream controllers, and
    // closing an already-closed controller throws. A live screen can dispose
    // on both _leave and State.dispose, so guard the double-call here.
    if (_disposed) return;
    _disposed = true;
    unawaited(_session.dispose());
  }

  /// Bridge a game's [GameReducer] to the session's String-keyed
  /// [LiveReducer]: map the wire intent name back to a [GameIntent] and run
  /// `def.reduce`. An unknown name (the session's internal `hello` sync
  /// ping, or any future control message) is a no-op that just triggers a
  /// canonical rebroadcast — exactly the old `default` behavior.
  static LiveReducer _adapt(GameDefinition<dynamic> def) {
    return (state, intent, args) {
      final mapped = _intentByName(intent);
      return mapped == null ? state : def.reduce(state, mapped, args);
    };
  }

  static GameIntent? _intentByName(String name) {
    for (final i in GameIntent.values) {
      if (i.name == name) return i;
    }
    return null;
  }
}
