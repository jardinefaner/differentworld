import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/growth_arc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildGrowthArc', () {
    test('empty collection → a gentle "story begins" arc', () {
      final beats = buildGrowthArc(
        firstName: 'Mia',
        collection: const ActionWordsCollection(
          worldCounts: {},
          verbTotals: {},
          dayCount: 0,
        ),
      );
      expect(beats.length, 2);
      expect(beats.first.kind, DayBeatKind.open);
      expect(beats.first.big, 'Mia');
      expect(beats.last.kind, DayBeatKind.close);
    });

    test('blank name falls back to "You"', () {
      final beats = buildGrowthArc(
        firstName: '   ',
        collection: const ActionWordsCollection(
          worldCounts: {},
          verbTotals: {},
          dayCount: 0,
        ),
      );
      expect(beats.first.big, 'You');
    });

    test('populated collection compiles the full story arc', () {
      final beats = buildGrowthArc(
        firstName: 'Leo',
        collection: const ActionWordsCollection(
          // 'ant' is a canonical named world; verbs are real ids.
          worldCounts: {'ant': 3},
          verbTotals: {'listen': 5, 'help': 3, 'build': 2},
          dayCount: 7,
        ),
      );

      // Opens with the child + the day count.
      expect(beats.first.kind, DayBeatKind.open);
      expect(beats.first.big, 'Leo');
      expect(beats.first.sub, contains('7 days'));

      // A verbs beat with the most-practiced first (Listen, 5×).
      final verbBeat = beats.firstWhere((b) => b.kind == DayBeatKind.verbs);
      expect(verbBeat.lines.first, contains('Listen'));
      expect(verbBeat.lines.first, contains('5×'));

      // At least one world beat resolved from the id.
      expect(
        beats.where(
          (b) => b.kind == DayBeatKind.open && b.label.contains('days as'),
        ),
        isNotEmpty,
      );

      // The emerging title lands as a `name` beat.
      expect(beats.any((b) => b.kind == DayBeatKind.name), isTrue);

      // Always ends on the close.
      expect(beats.last.kind, DayBeatKind.close);
    });

    test('singular day label', () {
      final beats = buildGrowthArc(
        firstName: 'Sam',
        collection: const ActionWordsCollection(
          worldCounts: {},
          verbTotals: {'play': 1},
          dayCount: 1,
        ),
      );
      expect(beats.first.sub, contains('1 day.'));
    });

    test('photos are woven in as photo beats, capped at 6', () {
      final beats = buildGrowthArc(
        firstName: 'Ada',
        collection: const ActionWordsCollection(
          worldCounts: {'ant': 2},
          verbTotals: {'build': 4},
          dayCount: 5,
        ),
        photos: List.generate(
          8,
          (i) => (url: 'path/$i.jpg', caption: 'May ${i + 1}'),
        ),
      );
      final photoBeats = beats
          .where((b) => b.kind == DayBeatKind.photo)
          .toList();
      expect(photoBeats, hasLength(6)); // capped
      expect(photoBeats.first.imageUrl, 'path/0.jpg');
      expect(photoBeats.first.big, 'May 1');
      // The open beat still leads; photos come after.
      expect(beats.first.kind, DayBeatKind.open);
      expect(
        beats.indexWhere((b) => b.kind == DayBeatKind.photo),
        greaterThan(0),
      );
    });

    test('no photos → no photo beats (arc unchanged)', () {
      final beats = buildGrowthArc(
        firstName: 'Ada',
        collection: const ActionWordsCollection(
          worldCounts: {'ant': 1},
          verbTotals: {'build': 1},
          dayCount: 1,
        ),
      );
      expect(beats.any((b) => b.kind == DayBeatKind.photo), isFalse);
    });
  });
}
