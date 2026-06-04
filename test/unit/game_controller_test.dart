// The game framework core (docs/GAMES.md, VISION #17): a game is a pure
// reducer over the shared intent vocabulary, driven by a GameController.
// This exercises the local path with a tiny counter game.

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal game: `next` advances an index, `tally` bumps a count by
/// `args['by']` (default 1), `reset` zeroes both. Other intents no-op.
Map<String, dynamic> _counterReduce(
  Map<String, dynamic> s,
  GameIntent intent,
  Map<String, dynamic> args,
) {
  final next = Map<String, dynamic>.from(s);
  switch (intent) {
    case GameIntent.next:
      next['i'] = (s['i'] as int) + 1;
    case GameIntent.tally:
      next['count'] = (s['count'] as int) + ((args['by'] as int?) ?? 1);
    case GameIntent.reset:
      next['i'] = 0;
      next['count'] = 0;
    case GameIntent.back:
    case GameIntent.reveal:
    case GameIntent.pick:
    case GameIntent.capture:
    case GameIntent.submit:
      break;
  }
  return next;
}

void main() {
  group('LocalGameController', () {
    test('applies the reducer and emits the new state', () async {
      final c = LocalGameController(
        initial: {'i': 0, 'count': 0},
        reduce: _counterReduce,
      );
      addTearDown(c.dispose);

      expect(c.state['i'], 0);
      final emitted = <int>[];
      final sub = c.states.listen((s) => emitted.add(s['i'] as int));

      c.send(GameIntent.next);
      expect(c.state['i'], 1);

      c.send(GameIntent.tally, {'by': 3});
      expect(c.state['count'], 3, reason: 'tally adds args["by"]');
      expect(c.state['i'], 1, reason: 'tally leaves the index alone');

      c.send(GameIntent.reset);
      expect(c.state['i'], 0);
      expect(c.state['count'], 0);

      // Broadcast streams deliver asynchronously — flush microtasks.
      await Future<void>.delayed(Duration.zero);
      expect(emitted, [1, 1, 0], reason: 'one emit per send, with the i value');
      await sub.cancel();
    });

    test('reset reseeds with FRESH content when a reseed is wired', () {
      // Each reseed yields a new round (a different payload), standing in for
      // the content engine's never-repeat memory — "play again" = new
      // questions, not a replay.
      var round = 0;
      final c = LocalGameController(
        initial: {'i': 2, 'count': 5, 'q': 'round-0'},
        reduce: _counterReduce,
        reseed: () => {'i': 0, 'count': 0, 'q': 'round-${++round}'},
      );
      addTearDown(c.dispose);

      c.send(GameIntent.reset);
      expect(c.state['q'], 'round-1', reason: 'reset pulled fresh content');
      expect(c.state['i'], 0);

      c.send(GameIntent.reset);
      expect(c.state['q'], 'round-2', reason: 'each replay is a new round');
    });

    test('without a reseed, reset replays the same content via the reducer',
        () {
      final c = LocalGameController(
        initial: {'i': 3, 'count': 7, 'q': 'fixed'},
        reduce: _counterReduce,
      );
      addTearDown(c.dispose);

      c.send(GameIntent.reset);
      expect(c.state['q'], 'fixed', reason: 'same content kept (seed games)');
      expect(c.state['i'], 0, reason: 'the reducer still zeroes indices');
    });

    test('the reducer is pure — it never mutates the input state', () {
      final initial = {'i': 0, 'count': 0};
      final next = _counterReduce(initial, GameIntent.next, const {});
      expect(initial['i'], 0, reason: 'input untouched');
      expect(next['i'], 1, reason: 'a new state is returned');
    });

    test('back / reveal / pick / capture / submit are no-ops here', () {
      final c = LocalGameController(
        initial: {'i': 5, 'count': 2},
        reduce: _counterReduce,
      );
      addTearDown(c.dispose);
      [
        GameIntent.back,
        GameIntent.reveal,
        GameIntent.pick,
        GameIntent.capture,
        GameIntent.submit,
      ].forEach(c.send);
      expect(c.state, {'i': 5, 'count': 2});
    });

    // Regression: the GameController contract says dispose is idempotent, and
    // send-after-dispose must not throw (no add to a closed sink). This pins
    // the contract LiveGameController also honors via its _disposed guard —
    // the class of bug Wave 0c's preflight caught on the live path.
    test('dispose is idempotent; send after dispose is a safe no-op', () {
      final c = LocalGameController(
        initial: {'i': 0, 'count': 0},
        reduce: _counterReduce,
      )..dispose();
      expect(c.dispose, returnsNormally, reason: 'double dispose is safe');
      expect(
        () => c.send(GameIntent.tally),
        returnsNormally,
        reason: 'no add to a closed sink',
      );
    });
  });
}
