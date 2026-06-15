import 'package:differentworld/features/action_words/day_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// The live-instrument batch: the phone becomes a conductor's score. These pin
/// that EVERY beat has a staff cue (so the phone never goes silent mid-run),
/// that an authored cue overrides the template, and that the next-beat label
/// is always present.
void main() {
  group('beatGuidance', () {
    test('every beat kind has a non-empty staff cue', () {
      for (final kind in DayBeatKind.values) {
        expect(
          beatGuidance(DayBeat(kind: kind)).trim(),
          isNotEmpty,
          reason: 'kind $kind has no guidance',
        );
      }
    });

    test('an authored guidance overrides the template', () {
      const authored = 'Say it twice, then wait for a hand.';
      expect(
        beatGuidance(
          const DayBeat(kind: DayBeatKind.play, guidance: authored),
        ),
        authored,
      );
    });

    test('blank/whitespace guidance falls back to the template', () {
      final g = beatGuidance(
        const DayBeat(kind: DayBeatKind.play, guidance: '   '),
      );
      expect(g.trim(), isNotEmpty);
      expect(g.contains('play'), isTrue); // the templated play cue
    });
  });

  group('beatKindShortLabel', () {
    test('every kind has a short label for the Next control', () {
      for (final kind in DayBeatKind.values) {
        expect(
          beatKindShortLabel(kind).trim(),
          isNotEmpty,
          reason: 'kind $kind has no label',
        );
      }
    });
  });
}
