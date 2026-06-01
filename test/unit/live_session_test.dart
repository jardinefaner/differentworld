// The live-session reducer + state serialization (docs/LIVE_SESSIONS.md).
// Pure — the presenter applies reduce() to controller intents; the wire
// carries toMap()/fromMap(). The Realtime transport itself isn't unit-
// tested (needs a live server), but the logic + protocol shape are.

import 'package:differentworld/features/live_session/live_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveState.reduce', () {
    const total = 8;

    test('next advances and clears the reveal', () {
      const s = LiveState(index: 2, revealed: true);
      final r = LiveState.reduce(s, 'next', total);
      expect(r.index, 3);
      expect(r.revealed, isFalse);
      expect(r.done, isFalse);
    });

    test('next on the last slide ends the round', () {
      const s = LiveState(index: total - 1);
      expect(LiveState.reduce(s, 'next', total).done, isTrue);
    });

    test('next when already done is a no-op', () {
      const s = LiveState(index: total - 1, done: true);
      final r = LiveState.reduce(s, 'next', total);
      expect(r.done, isTrue);
      expect(r.index, total - 1);
    });

    test('back decrements and clears reveal; stops at 0', () {
      expect(LiveState.reduce(const LiveState(index: 3, revealed: true), 'back', total).index, 2);
      expect(LiveState.reduce(const LiveState(), 'back', total).index, 0);
    });

    test('back from done un-dones (returns to the last slide)', () {
      const s = LiveState(index: total - 1, done: true);
      expect(LiveState.reduce(s, 'back', total).done, isFalse);
    });

    test('reveal toggles', () {
      expect(LiveState.reduce(const LiveState(), 'reveal', total).revealed, isTrue);
      expect(
        LiveState.reduce(const LiveState(revealed: true), 'reveal', total).revealed,
        isFalse,
      );
    });

    test('restart resets everything', () {
      const s = LiveState(index: 5, revealed: true, done: true);
      final r = LiveState.reduce(s, 'restart', total);
      expect(r.index, 0);
      expect(r.revealed, isFalse);
      expect(r.done, isFalse);
    });

    test('hello / unknown intents are no-ops (trigger a rebroadcast only)', () {
      const s = LiveState(index: 4, revealed: true);
      final r = LiveState.reduce(s, 'hello', total);
      expect(r.index, 4);
      expect(r.revealed, isTrue);
    });
  });

  group('LiveState wire format', () {
    test('round-trips through toMap/fromMap', () {
      const s = LiveState(index: 6, revealed: true);
      final r = LiveState.fromMap(s.toMap());
      expect(r.index, 6);
      expect(r.revealed, isTrue);
      expect(r.done, isFalse);
    });

    test('fromMap tolerates missing / wrong-typed keys', () {
      expect(LiveState.fromMap(const {}).index, 0);
      expect(LiveState.fromMap(const {}).revealed, isFalse);
      expect(LiveState.fromMap({'i': 3, 'r': true, 'd': true}).done, isTrue);
    });
  });

  test('topicFor is stable + case-insensitive', () {
    expect(LiveSession.topicFor('rj4k'), LiveSession.topicFor('RJ4K'));
    expect(LiveSession.topicFor('AB2C'), 'dw-session-AB2C');
  });
}
