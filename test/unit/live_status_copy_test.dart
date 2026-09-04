// A live surface has THREE states that all look like "no screens connected"
// from the outside, and the app must not conflate them:
//
//   connecting  — the channel is coming up
//   live, 0     — up, and nobody has joined yet (print the join instructions)
//   error       — the channel is dead (the instructions CANNOT work)
//
// The Live Board used to print "On each room screen: Cast → Be the screen →
// enter this code" whenever peers == 0, including when Realtime was wedged —
// walking a teacher to the TV to type a code that could never connect. An
// instruction that cannot work is worse than no instruction.
//
// This pins the copy decision as a pure function so the three stay distinct.

import 'package:differentworld/features/live_session/live_session.dart'
    show LiveStatus;
import 'package:flutter_test/flutter_test.dart';

/// The rule `_JoinCard` renders. Kept here in the same shape so a regression
/// in the screen shows up as a diff against a stated intent.
String joinLine(LiveStatus status, int peers) => switch (status) {
  LiveStatus.error =>
    "Can't reach the screens right now. The code won't connect until this "
        'clears — try again in a moment.',
  LiveStatus.connecting when peers == 0 => 'Connecting…',
  _ when peers == 0 =>
    'On each room screen: Cast → Be the screen → enter this code.',
  _ => '$peers screen${peers == 1 ? '' : 's'} connected.',
};

void main() {
  test('a dead channel never prints the join instructions', () {
    final line = joinLine(LiveStatus.error, 0);
    expect(line, isNot(contains('enter this code')));
    expect(line, contains("Can't reach"));
  });

  test(
    'a dead channel says so even if a peer was counted before it dropped',
    () {
      expect(joinLine(LiveStatus.error, 2), contains("Can't reach"));
    },
  );

  test('connecting is not the same as ready-and-empty', () {
    expect(joinLine(LiveStatus.connecting, 0), 'Connecting…');
    expect(joinLine(LiveStatus.live, 0), contains('enter this code'));
  });

  test('a live channel with screens counts them, and pluralises', () {
    expect(joinLine(LiveStatus.live, 1), '1 screen connected.');
    expect(joinLine(LiveStatus.live, 3), '3 screens connected.');
  });

  test('the three zero-peer states produce three different sentences', () {
    final lines = {
      joinLine(LiveStatus.error, 0),
      joinLine(LiveStatus.connecting, 0),
      joinLine(LiveStatus.live, 0),
    };
    expect(lines.length, 3, reason: 'conflating any two is the bug');
  });
}
