import 'package:differentworld/features/action_words/time_capsule.dart';
import 'package:differentworld/features/action_words/wall.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WallNoteType', () {
    test('round-trips by name, falls back to free', () {
      for (final t in WallNoteType.values) {
        expect(WallNoteType.fromName(t.name), t);
      }
      expect(WallNoteType.fromName('nonsense'), WallNoteType.free);
      expect(WallNoteType.fromName(null), WallNoteType.free);
    });
  });

  group('capsuleIsSealed (date-only)', () {
    final now = DateTime(2026, 7, 15, 13);

    test('future date → sealed', () {
      expect(capsuleIsSealed(DateTime(2026, 7, 20), now), isTrue);
    });

    test('same day → open (the day it opens, it opens)', () {
      expect(capsuleIsSealed(DateTime(2026, 7, 15, 23), now), isFalse);
    });

    test('past date → open', () {
      expect(capsuleIsSealed(DateTime(2026, 7, 2), now), isFalse);
    });

    test('null seal → never sealed', () {
      expect(capsuleIsSealed(null, now), isFalse);
    });
  });
}
