import 'package:differentworld/features/games/game.dart';

/// The run-script's cursor, in the WIRE state.
///
/// Putting it here rather than in a widget's `State` is the whole point: a
/// paired cast receiver renders from the wire and nothing else, so a cursor
/// held on the phone would brief the phone and leave the room — the people the
/// instructions are FOR — looking at a board nobody explained. In the wire, one
/// tap moves the phone and the television together.
///
/// It rides the existing `next` / `back` intents rather than introducing an
/// intent of its own. That is deliberate and it is the cheap half of the
/// feature: every control a substitute already has — the scaffold's buttons,
/// the cast cockpit's Next, the presenter keyboard's arrow keys — drives the
/// briefing with no new wiring, because from the outside it is the same verb.
/// "Next, next, next" is one gesture whether it is advancing the rules or the
/// round.
abstract class RunScriptWire {
  /// Reserved wire key. Short because it crosses the Realtime wire on every
  /// intent, and namespaced enough that no game reducer will collide.
  static const String key = 'brief';

  /// Which beat the room is on, or null when the briefing is over and the
  /// board owns the screen. Absent means DONE, not "not started" — a game
  /// that never seeds it simply has no script.
  static int? indexOf(Map<String, dynamic> wire) {
    final at = wire[key];
    return at is int ? at : null;
  }

  /// Start a round at its first beat, when the game has a script to give.
  /// Games do not do this themselves: a script is framework behaviour, and
  /// asking 41 `initialState` overrides to remember a key is how a feature
  /// ends up working in the eleven games somebody got to.
  static Map<String, dynamic> seed(
    GameDefinition<dynamic> def,
    Map<String, dynamic> wire,
  ) {
    if (def.howToPlay.isEmpty || wire.containsKey(key)) return wire;
    return {...wire, key: 0};
  }

  /// Apply an intent, briefing first.
  ///
  /// While the room is being briefed the GAME does not advance at all — every
  /// other intent is swallowed. A stray tap on the board during the rules must
  /// not quietly start play behind the instructions, because the adult reading
  /// them aloud would never see that it had.
  static Map<String, dynamic> reduce(
    GameDefinition<dynamic> def,
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final at = indexOf(state);
    if (at == null) {
      final next = def.reduce(state, intent, args);
      // Play again re-briefs, and this has to live on the PLAIN path: by the
      // time anyone taps reset the briefing is long over, so a reset branch
      // inside the briefing switch below was unreachable code that read like
      // a working feature. Caught by the test, not by review.
      return intent == GameIntent.reset ? seed(def, next) : next;
    }

    switch (intent) {
      case GameIntent.next:
        final n = at + 1;
        if (n >= def.howToPlay.length) {
          // Past the last beat: the key goes away and the board takes over.
          return {...state}..remove(key);
        }
        return {...state, key: n};
      case GameIntent.back:
        return at == 0 ? state : {...state, key: at - 1};
      case GameIntent.reset:
        // Already on beat 0 and the round has not started; restart the deal
        // but stay in the briefing.
        return seed(def, {...def.reduce(state, intent, args)}..remove(key));
      case GameIntent.pick:
      case GameIntent.reveal:
      case GameIntent.tick:
      case GameIntent.tally:
      case GameIntent.capture:
      case GameIntent.submit:
        return state;
    }
  }
}
