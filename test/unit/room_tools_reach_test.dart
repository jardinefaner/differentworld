// Room tools exists because the instruments were built and unreachable from
// inside a running activity (docs/FACILITATION.md, facet 5): a counselor
// mid-Bingo who needed to pick a child had to leave, walk back to the deck,
// find the card, and lose their place.
//
// It then shipped on ONE of the four surfaces that run a game, and the one it
// reached was the one where leaving costs least. On the CAST cockpit — where
// leaving means stopping the room's screen — it was absent.
//
// The rule follows from GameAudience: a surface that is a phone in a HAND
// (host, remote) reaches the instruments; a surface that is a room's SCREEN
// (room, presenter) does not, because nobody is holding it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  /// A phone in a hand, driving a game.
  const inTheHand = <String, String>{
    'lib/features/games/game_scaffold.dart': 'the single device',
    'lib/features/live_session/cast_cockpit.dart': 'the cast remote',
    'lib/features/live_session/live_game_screen.dart': 'the live controller',
  };

  /// A screen in a room. Nobody is holding it, so an instrument picker on it
  /// is a control the room would have to walk up and touch.
  const onTheWall = <String, String>{
    'lib/features/live_session/cast_receiver.dart': 'the cast receiver',
    'lib/features/games/game_fullscreen.dart': 'the fullscreen present',
  };

  test('every phone-in-hand surface can reach the instruments', () {
    for (final entry in inTheHand.entries) {
      expect(
        read(entry.key).contains('RoomToolsButton'),
        isTrue,
        reason:
            '${entry.value} runs a game from a hand and cannot pick a name, '
            'start a timer or flash "eyes up" without leaving it',
      );
    }
  });

  test('a room screen offers no instrument picker', () {
    for (final entry in onTheWall.entries) {
      expect(
        read(entry.key).contains('RoomToolsButton'),
        isFalse,
        reason: '${entry.value} is a display; nobody is holding it',
      );
    }
  });

  test('the scan is looking at real files', () {
    // Without this the suite passes vacuously the day a file is renamed.
    for (final path in [...inTheHand.keys, ...onTheWall.keys]) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(read(path).length, greaterThan(500), reason: path);
    }
  });
}
