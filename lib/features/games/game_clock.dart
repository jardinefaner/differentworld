import 'dart:async';

import 'package:differentworld/features/games/game.dart';

/// **The heartbeat for a game that has one**, wound by whoever holds the
/// reducer.
///
/// Three games are nothing without it — Whack-a-Mole's mole never moves,
/// Simon never plays its sequence back, Boggle's sand never runs out — and
/// exactly ONE surface used to wind it: the single-device runner, in a private
/// method of its State. So all three worked in a hand and froze everywhere
/// else. Cast Whack-a-Mole to the TV a substitute just set up and the room
/// watches a still picture of a mole.
///
/// It belongs to the AUTHORITY — the object that reduces — and not to a view,
/// for a reason worth keeping: there is exactly ONE authority per session
/// however many screens are looking at it. A clock living in `GameView` would
/// run twice the moment a presenter opened the fullscreen stage over its own
/// board, because the board underneath stays mounted. "One per session" is a
/// property of the controller, so that is where the clock lives.
///
/// Every method is safe to call more than once and in any order; a clock that
/// has stopped stays stopped until it is pointed at a game again.
class GameClock {
  /// Wind the clock for [def], if it has one, calling [onTick] on every beat.
  /// A game without a clock costs nothing — no timer is created at all.
  ///
  /// Re-pointing at the same game keeps the current beat rather than
  /// restarting it, so a re-cast of the game already on screen doesn't reset
  /// the mole's rhythm mid-round; pointing at a different game (or at null)
  /// stops the old one first.
  void follow(GameDefinition<dynamic>? def, void Function() onTick) {
    if (def != null && def.id == _followingId && _timer != null) return;
    stop();
    if (def == null || !def.ticks) return;
    _followingId = def.id;
    _timer = Timer.periodic(def.tickEvery, (_) => onTick());
  }

  /// Stop, and forget what we were following. A periodic timer outliving its
  /// owner is the classic leak, so every owner calls this from `dispose`.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _followingId = null;
  }

  /// Whether a beat is currently running — for tests, and for an owner that
  /// wants to know without reaching into the timer.
  bool get running => _timer != null;

  Timer? _timer;
  String? _followingId;
}
