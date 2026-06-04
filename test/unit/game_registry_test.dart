// The game registry — the keystone for "one place to join" a live session
// (docs/LIVE_SESSIONS.md): a joiner resolves a session's advertised game id to
// the right GameDefinition here, without knowing the game in advance.

import 'package:differentworld/features/games/game_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gameById resolves every registered game', () {
    for (final game in liveGames) {
      expect(gameById(game.id), same(game), reason: 'id ${game.id}');
    }
  });

  test('an unknown id resolves to null (graceful degrade)', () {
    expect(gameById('no-such-game'), isNull);
    expect(gameById(''), isNull);
  });

  test('ids are unique across the registry', () {
    final ids = liveGames.map((g) => g.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('the well-known games are present', () {
    for (final id in const ['this-or-that', 'charades', 'riddles', 'poll']) {
      expect(gameById(id), isNotNull, reason: id);
    }
  });
}
