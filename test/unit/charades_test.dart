// Charades on the unified game framework (docs/GAMES.md). The pure reducer
// over GameIntent, the content shape, and the secret-role surface. Two-device
// transport isn't unit-tested (needs a live server), but the rules + wire
// format are.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const game = CharadesGame();

  // A small explicit 5-prompt state so the rules read clearly.
  Map<String, dynamic> stateAt({int i = 0, int f = 0, bool d = false, int n = 5}) {
    return {
      'i': i,
      'f': f,
      'd': d,
      'n': n,
      'items': [for (var k = 0; k < n; k++) ['word$k', 'cat$k']],
    };
  }

  Map<String, dynamic> apply(Map<String, dynamic> s, GameIntent intent) =>
      game.reduce(s, intent, const {});

  group('CharadesGame.reduce', () {
    test('Got it (tally) counts it and advances', () {
      final r = apply(stateAt(i: 1, f: 2), GameIntent.tally);
      expect(r['f'], 3);
      expect(r['i'], 2);
      expect(r['d'], isFalse);
    });

    test('Got it on the last prompt counts it and ends', () {
      final r = apply(stateAt(i: 4, f: 4), GameIntent.tally);
      expect(r['f'], 5);
      expect(r['d'], isTrue);
    });

    test('Skip (next) advances without counting', () {
      final r = apply(stateAt(i: 1, f: 2), GameIntent.next);
      expect(r['f'], 2);
      expect(r['i'], 2);
    });

    test('Skip on the last prompt ends without counting', () {
      final r = apply(stateAt(i: 4, f: 2), GameIntent.next);
      expect(r['d'], isTrue);
      expect(r['f'], 2);
    });

    test('Got it / Skip are no-ops once done', () {
      final done = stateAt(i: 4, f: 5, d: true);
      expect(apply(done, GameIntent.tally)['f'], 5);
      expect(apply(done, GameIntent.next)['i'], 4);
    });

    test('Reset clears progress but keeps the prompts', () {
      final r = apply(stateAt(i: 3, f: 3, d: true), GameIntent.reset);
      expect(r['i'], 0);
      expect(r['f'], 0);
      expect(r['d'], isFalse);
      expect((r['items'] as List).length, 5); // content survives a reset
    });
  });

  group('content + decode', () {
    test('initialState pulls words + categories from the bank', () {
      final s = game.initialState(LocalContentBank.seeded());
      final n = s['n'] as int;
      final items = s['items'] as List;
      expect(n, greaterThan(0));
      expect(items.length, n);
      for (final it in items) {
        final pair = it as List;
        expect((pair[0] as String).trim(), isNotEmpty); // word
        expect((pair[1] as String).trim(), isNotEmpty); // category
      }
    });

    test('decode exposes the current word + category; secret role on', () {
      final s = game.decode(stateAt(i: 1));
      expect(s.word, 'word1');
      expect(s.category, 'cat1');
      expect(s.total, 5);
      expect(game.hasSecretRole, isTrue);
    });
  });

  group('activeIntents', () {
    test('in play: Got it + Skip; done: Play again', () {
      expect(
        game.activeIntents(game.decode(stateAt())),
        {GameIntent.tally, GameIntent.next},
      );
      expect(
        game.activeIntents(game.decode(stateAt(d: true))),
        {GameIntent.reset},
      );
    });
  });

  test('charades seed: every prompt has a word + a category', () {
    final prompts = LocalContentBank.seeded().take(ContentKind.charades, 100);
    expect(prompts.length, greaterThanOrEqualTo(16));
    for (final p in prompts) {
      expect((p.payload['word']! as String).trim(), isNotEmpty);
      expect((p.payload['category']! as String).trim(), isNotEmpty);
    }
  });
}
