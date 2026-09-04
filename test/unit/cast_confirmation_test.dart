// The one-tap cast confirms out loud, and the confirmation must not overstate
// what happened.
//
// `CastSnapshot.active` means a session OBJECT exists — a code is up — not
// that any screen has joined it. The original copy said "X is on the screen"
// in both cases, and the failure is social rather than technical: a staffer
// reads it, says "everyone look at the screen", and the room looks at a join
// code. That is worse than no confirmation at all.
//
// Testing the sentence rather than the widget is deliberate. The branch sits
// behind a live Realtime session, which a widget test cannot stand up without
// a real CastSession — so the claim would have gone uncovered exactly where it
// mattered. A pure function moves it somewhere a test can reach.

import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('with a screen watching, it says the thing is on the screen', () {
    expect(
      castConfirmation('Riddle Me This', 1),
      'Riddle Me This is on the screen',
    );
    expect(castConfirmation('Potions', 3), 'Potions is on the screen');
  });

  test('with nothing watching, it does NOT claim the screen shows it', () {
    final msg = castConfirmation('Riddle Me This', 0);
    expect(
      msg.contains('is on the screen'),
      isFalse,
      reason:
          'no screen has joined, so this would send a staffer to point at '
          'a join code in front of the room',
    );
    expect(msg, 'Riddle Me This shows as soon as a screen connects');
  });

  test('it still reads as a confirmation with no screen', () {
    // The cast DID happen — the state is queued and a screen joining later
    // receives it, because the presenter re-publishes on presence sync. So
    // this is a tense change, not an error message.
    final msg = castConfirmation('Potions', 0);
    expect(msg.toLowerCase(), isNot(contains('fail')));
    expect(msg.toLowerCase(), isNot(contains('error')));
    expect(msg.toLowerCase(), isNot(contains("couldn't")));
  });

  test('an unnamed cast still forms a sentence', () {
    expect(castConfirmation(null, 1), 'It is on the screen');
    expect(castConfirmation(null, 0), 'It shows as soon as a screen connects');
  });
}
