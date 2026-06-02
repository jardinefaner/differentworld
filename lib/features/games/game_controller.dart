import 'dart:async';

import 'package:differentworld/features/games/game.dart';

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
