// Charades on the generic LiveSession seam (docs/GAMES.md). Pure reducer +
// the seam wrapping + the content shape. Two-device transport isn't unit-
// tested (needs a live server), but the rules + wire format are.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/live_session/charades.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const total = 5;

  group('CharadesState.reduce', () {
    test('got counts it and advances', () {
      final r = CharadesState.reduce(const CharadesState(index: 1, found: 2), 'got', total);
      expect(r.found, 3);
      expect(r.index, 2);
      expect(r.done, isFalse);
    });

    test('got on the last prompt counts it and ends', () {
      final r = CharadesState.reduce(
        const CharadesState(index: total - 1, found: 4),
        'got',
        total,
      );
      expect(r.found, 5);
      expect(r.done, isTrue);
    });

    test('skip advances without counting', () {
      final r = CharadesState.reduce(const CharadesState(index: 1, found: 2), 'skip', total);
      expect(r.found, 2);
      expect(r.index, 2);
    });

    test('skip on the last prompt ends without counting', () {
      final r = CharadesState.reduce(
        const CharadesState(index: total - 1, found: 2),
        'skip',
        total,
      );
      expect(r.done, isTrue);
      expect(r.found, 2);
    });

    test('got/skip are no-ops once done', () {
      const s = CharadesState(index: total - 1, found: 5, done: true);
      expect(CharadesState.reduce(s, 'got', total).found, 5);
      expect(CharadesState.reduce(s, 'skip', total).index, total - 1);
    });

    test('restart resets; hello is a no-op', () {
      const s = CharadesState(index: 3, found: 3, done: true);
      final r = CharadesState.reduce(s, 'restart', total);
      expect(r.index, 0);
      expect(r.found, 0);
      expect(r.done, isFalse);
      expect(CharadesState.reduce(s, 'hello', total).found, 3);
    });
  });

  group('seam wiring', () {
    test('reducer(total) operates on the session map', () {
      final next = CharadesState.reducer(total)(
        const CharadesState().toMap(),
        'got',
        const {},
      );
      final s = CharadesState.fromMap(next);
      expect(s.found, 1);
      expect(s.index, 1);
    });

    test('round-trips through toMap/fromMap', () {
      const s = CharadesState(index: 4, found: 3);
      final r = CharadesState.fromMap(s.toMap());
      expect(r.index, 4);
      expect(r.found, 3);
      expect(r.done, isFalse);
    });
  });

  test('charades seed: every prompt has a word + a category', () {
    final bank = LocalContentBank.seeded();
    final prompts = bank.take(ContentKind.charades, 100);
    expect(prompts.length, greaterThanOrEqualTo(16));
    for (final p in prompts) {
      expect((p.payload['word']! as String).trim(), isNotEmpty);
      expect((p.payload['category']! as String).trim(), isNotEmpty);
    }
  });
}
