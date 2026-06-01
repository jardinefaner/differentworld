// The Pattern Maker core (docs/ACTIVITY_RUNTIME.md). Pure config + the
// kaleidoscope mirror rule — testable without a camera or an image.

import 'package:differentworld/features/activity_runtime/pattern_maker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PatternConfig', () {
    test('tileCount is the square of tilesPerRow', () {
      expect(const PatternConfig(tilesPerRow: 4).tileCount, 16);
      expect(const PatternConfig(tilesPerRow: 2).tileCount, 4);
    });

    test('kaleidoscope mirrors odd columns/rows; off mirrors nothing', () {
      const k = PatternConfig(kaleidoscope: true);
      expect(k.flipX(0), isFalse);
      expect(k.flipX(1), isTrue);
      expect(k.flipY(2), isFalse);
      expect(k.flipY(3), isTrue);

      const plain = PatternConfig(kaleidoscope: false);
      expect(plain.flipX(1), isFalse);
      expect(plain.flipY(3), isFalse);
    });

    test('copyWith changes one field and keeps the other', () {
      const base = PatternConfig();
      expect(base.copyWith(tilesPerRow: 6).tilesPerRow, 6);
      expect(base.copyWith(tilesPerRow: 6).kaleidoscope, base.kaleidoscope);
      expect(base.copyWith(kaleidoscope: false).kaleidoscope, isFalse);
      expect(base.copyWith(kaleidoscope: false).tilesPerRow, base.tilesPerRow);
    });

    test('catalog seeds are non-empty', () {
      expect(patternTileChoices, isNotEmpty);
      expect(patternPrompts, isNotEmpty);
      expect(patternPrompts.every((p) => p.trim().isNotEmpty), isTrue);
    });
  });
}
