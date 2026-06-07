import 'package:differentworld/features/action_words/summer_book.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

/// The "no broken-looking book" fix: a Summer Book walks a CONTINUOUS week
/// range so no week is silently skipped, and a gap is labelled honestly —
/// "quiet" (present, nothing logged) vs "away" (absent) — never an empty
/// content block that reads as neglect.
void main() {
  List<SummerBookWeekKind> kinds(
    List<({int week, SummerBookWeekKind kind})> ws,
  ) => [for (final w in ws) w.kind];

  List<int> weeks(List<({int week, SummerBookWeekKind kind})> ws) => [
    for (final w in ws) w.week,
  ];

  group('classifySummerWeeks', () {
    test('empty signal → no pages', () {
      expect(
        classifySummerWeeks(
          entryWeeks: const {},
          attendedWeeks: const {},
          tracksAttendance: false,
        ),
        isEmpty,
      );
    });

    test('fills gaps as QUIET when there is no attendance data', () {
      // entries in weeks 1 and 3, nothing tracked → week 2 is "quiet", never
      // "away" (we must not imply an absence we can't prove).
      final out = classifySummerWeeks(
        entryWeeks: const {1, 3},
        attendedWeeks: const {},
        tracksAttendance: false,
      );
      expect(weeks(out), [1, 2, 3]);
      expect(kinds(out), [
        SummerBookWeekKind.full,
        SummerBookWeekKind.quiet,
        SummerBookWeekKind.full,
      ]);
    });

    test('a present-but-unlogged gap is QUIET', () {
      final out = classifySummerWeeks(
        entryWeeks: const {1, 3},
        attendedWeeks: const {1, 2, 3},
        tracksAttendance: true,
      );
      expect(kinds(out), [
        SummerBookWeekKind.full,
        SummerBookWeekKind.quiet, // here, just nothing logged
        SummerBookWeekKind.full,
      ]);
    });

    test('an absent gap (tracked, no present record) is AWAY', () {
      final out = classifySummerWeeks(
        entryWeeks: const {1, 4},
        attendedWeeks: const {1, 4},
        tracksAttendance: true,
      );
      expect(weeks(out), [1, 2, 3, 4]);
      expect(kinds(out), [
        SummerBookWeekKind.full,
        SummerBookWeekKind.away,
        SummerBookWeekKind.away,
        SummerBookWeekKind.full,
      ]);
    });

    test('attendance extends the range past the last entry', () {
      // Present week 2 with no entry → the book still includes week 2 (quiet),
      // even though the last logged moment was week 1.
      final out = classifySummerWeeks(
        entryWeeks: const {1},
        attendedWeeks: const {1, 2},
        tracksAttendance: true,
      );
      expect(weeks(out), [1, 2]);
      expect(kinds(out), [
        SummerBookWeekKind.full,
        SummerBookWeekKind.quiet,
      ]);
    });

    test('a late mark counts as present (range starts there)', () {
      // Only attendance, no entries: weeks 2-3 present → both quiet, no holes.
      final out = classifySummerWeeks(
        entryWeeks: const {},
        attendedWeeks: const {2, 3},
        tracksAttendance: true,
      );
      expect(weeks(out), [2, 3]);
      expect(kinds(out), everyElement(SummerBookWeekKind.quiet));
    });
  });

  group('SummerBook.worldsVisited', () {
    SummerBookWeek wk(int week, SummerBookWeekKind kind) => SummerBookWeek(
      week: week,
      worldName: 'World $week',
      emoji: '🌍',
      color: const Color(0xFF6B5B95),
      question: '',
      verbs: const [],
      milestone: '',
      spell: '',
      ally: '',
      moments: const [],
      kind: kind,
    );

    test('away weeks do not count as a world visited', () {
      final book = SummerBook(
        firstName: 'Mateo',
        title: '',
        days: 10,
        weeks: [
          wk(1, SummerBookWeekKind.full),
          wk(2, SummerBookWeekKind.away),
          wk(3, SummerBookWeekKind.quiet),
        ],
      );
      // 3 pages, but only 2 worlds actually visited (week 2 was away).
      expect(book.weeks.length, 3);
      expect(book.worldsVisited, 2);
    });
  });
}
