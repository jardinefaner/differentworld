import 'package:differentworld/features/schedule/day_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DayTemplate.proposed', () {
    test('drafts a 7-block day that fills the window', () {
      final t = DayTemplate.proposed(
        startMinute: 15 * 60,
        endMinute: 18 * 60,
        worldName: 'Ocean',
      );
      expect(t.blocks.length, 7);
      expect(t.startMinute, 15 * 60);
      expect(t.endMinute, 18 * 60);
      // The flex blocks absorb the remainder, so the draft fills the window.
      expect((t.plannedMinutes - t.spanMinutes).abs(), lessThanOrEqualTo(2));
      expect(t.isOverfilled, isFalse);
    });

    test('names the world into the day + its world blocks', () {
      final t = DayTemplate.proposed(
        startMinute: 15 * 60,
        endMinute: 18 * 60,
        worldName: 'Ocean',
      );
      expect(t.name, 'Ocean day');
      expect(t.blocks.any((b) => b.label.contains('Ocean')), isTrue);
    });

    test('no world → generic naming, no "·" world tags', () {
      final t = DayTemplate.proposed(startMinute: 15 * 60, endMinute: 18 * 60);
      expect(t.name, 'Proposed day');
      expect(t.blocks.any((b) => b.label.contains('·')), isFalse);
    });

    test('the photo block is a "rotation" so the run-day auto-fills it', () {
      final t = DayTemplate.proposed(startMinute: 15 * 60, endMinute: 18 * 60);
      expect(
        t.blocks.any((b) => b.label.toLowerCase().contains('rotation')),
        isTrue,
      );
    });

    test('first + last blocks bookend the day (arrival → pickup)', () {
      final t = DayTemplate.proposed(startMinute: 15 * 60, endMinute: 18 * 60);
      expect(t.blocks.first.kind, DayBlockKind.arrival);
      expect(t.blocks.last.kind, DayBlockKind.pickup);
    });

    test('a short window never overfills (no floor pushing past the end)', () {
      final t = DayTemplate.proposed(
        startMinute: 15 * 60,
        endMinute: 15 * 60 + 90, // a 1.5h mini-day
      );
      expect(t.isOverfilled, isFalse);
      expect(t.plannedMinutes, lessThanOrEqualTo(t.spanMinutes));
    });

    test('adapts to a longer window — flex blocks absorb the extra', () {
      final short = DayTemplate.proposed(startMinute: 15 * 60, endMinute: 18 * 60);
      final long = DayTemplate.proposed(startMinute: 14 * 60, endMinute: 19 * 60);
      expect(long.blocks.length, 7);
      expect(long.plannedMinutes, greaterThan(short.plannedMinutes));
      // Bookends stay 15m; only the program blocks grow.
      expect(long.blocks.first.minutes, short.blocks.first.minutes);
    });
  });
}
