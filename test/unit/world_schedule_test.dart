import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 15);

  group('curriculumWeekFor', () {
    test('null start → not active', () {
      expect(curriculumWeekFor(null, now), isNull);
    });

    test('start today → week 1', () {
      expect(curriculumWeekFor(now, now), 1);
    });

    test('advances one week every 7 days', () {
      expect(curriculumWeekFor(now.subtract(const Duration(days: 7)), now), 2);
      expect(curriculumWeekFor(now.subtract(const Duration(days: 13)), now), 2);
      expect(curriculumWeekFor(now.subtract(const Duration(days: 14)), now), 3);
      expect(
        curriculumWeekFor(now.subtract(const Duration(days: 63)), now),
        10,
      );
    });

    test('past week 10 → not active', () {
      expect(
        curriculumWeekFor(now.subtract(const Duration(days: 70)), now),
        isNull,
      );
    });

    test('before the start date → not active', () {
      expect(curriculumWeekFor(now.add(const Duration(days: 3)), now), isNull);
    });

    test('ignores time-of-day (date-only)', () {
      final startAfternoon = DateTime(2026, 7, 15, 16, 30);
      final morning = DateTime(2026, 7, 15, 8);
      expect(curriculumWeekFor(startAfternoon, morning), 1);
    });
  });

  group('startDateForWeek round-trips', () {
    test('jumping to week N makes now land in week N', () {
      for (var week = 1; week <= 10; week++) {
        final start = startDateForWeek(week, now);
        expect(
          curriculumWeekFor(start, now),
          week,
          reason: 'week $week did not round-trip',
        );
      }
    });
  });
}
