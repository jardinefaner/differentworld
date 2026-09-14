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

  /// The one way back INTO the briefing once it is over: `reveal` carrying
  /// `{'rules': true}`. On a plain `reveal` a riddle shows its answer and a
  /// board ignores it; the flag makes the request unambiguous, and riding an
  /// existing intent keeps the vocabulary closed. The wrap beat's "How to
  /// play" and the top pill's rules button both send this — and because it
  /// goes through the wire, a paired room screen re-briefs with the phone.
  static const String rulesArg = 'rules';

  /// Whether [intent] + [args] is a request to show the rules again.
  static bool isRulesRequest(GameIntent intent, Map<String, dynamic> args) =>
      intent == GameIntent.reveal && args[rulesArg] == true;

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
    if (isRulesRequest(intent, args)) {
      // Back to beat one, whatever the board is doing. The board's state is
      // untouched underneath — the rules are a glance over it, and "Start"
      // returns to exactly the round that was in progress.
      return def.howToPlay.isEmpty ? state : {...state, key: 0};
    }
    final at = indexOf(state);
    if (at == null) {
      // Play again does NOT re-brief. A room that has just finished a round
      // knows the rules; four taps of instructions between every round is the
      // sign-on-a-wall the half-second rule warns about, and it is what makes
      // people tap through a briefing without reading it the ONE time it
      // matters — the first. The rules stay one tap away ([rulesArg]).
      return def.reduce(state, intent, args);
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
