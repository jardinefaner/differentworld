import 'package:differentworld/features/schedule/day_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DayBlock block(
    String id,
    int minutes, [
    DayBlockKind k = DayBlockKind.activity,
  ]) => DayBlock(id: id, label: 'b$id', minutes: minutes, kind: k);

  group('clockLabel', () {
    test('formats minutes-from-midnight as 12-hour', () {
      expect(clockLabel(0), '12:00 AM');
      expect(clockLabel(540), '9:00 AM');
      expect(clockLabel(615), '10:15 AM');
      expect(clockLabel(720), '12:00 PM');
      expect(clockLabel(1095), '6:15 PM');
      expect(clockLabel(23 * 60 + 5), '11:05 PM');
    });
  });

  group('durationLabel', () {
    test('friendly h/m', () {
      expect(durationLabel(45), '45m');
      expect(durationLabel(60), '1h');
      expect(durationLabel(75), '1h 15m');
      expect(durationLabel(-20), '-20m');
    });
  });

  group('DayTemplate packing', () {
    test('derives clock windows by packing durations from start', () {
      final t = DayTemplate(
        id: 't',
        name: 'Day',
        startMinute: 540, // 9:00
        endMinute: 540 + 120, // 11:00
        blocks: [block('1', 15), block('2', 45), block('3', 15)],
      );
      final s = t.schedule;
      expect(s.map((e) => e.startMinute).toList(), [540, 555, 600]);
      expect(s.map((e) => e.endMinute).toList(), [555, 600, 615]);
      expect(t.plannedMinutes, 75);
      expect(t.spanMinutes, 120);
      expect(t.freeMinutes, 45);
      expect(t.isOverfilled, isFalse);
    });

    test('overfilled when blocks exceed the span', () {
      final t = DayTemplate(
        id: 't',
        name: 'Day',
        startMinute: 540,
        endMinute: 540 + 30,
        blocks: [block('1', 45), block('2', 15)],
      );
      expect(t.freeMinutes, -30);
      expect(t.isOverfilled, isTrue);
      // The last block still runs past the end — we don't clip it.
      expect(t.schedule.last.endMinute, 540 + 60);
    });

    test('empty blocks → whole span free', () {
      const t = DayTemplate(
        id: 't',
        name: 'Day',
        startMinute: 540,
        endMinute: 600,
        blocks: [],
      );
      expect(t.schedule, isEmpty);
      expect(t.freeMinutes, 60);
    });
  });

  group('json round-trip', () {
    test('encode/decode preserves the library', () {
      final library = [
        DayTemplate(
          id: 'a',
          name: 'Regular day',
          startMinute: 900,
          endMinute: 1080,
          blocks: [
            block('1', 15, DayBlockKind.arrival),
            block('2', 45, DayBlockKind.outdoor),
          ],
        ),
        DayTemplate.starter(name: 'Field trip'),
      ];
      final restored = decodeDayTemplates(encodeDayTemplates(library));
      expect(restored.length, 2);
      expect(restored[0].id, 'a');
      expect(restored[0].name, 'Regular day');
      expect(restored[0].startMinute, 900);
      expect(restored[0].blocks.length, 2);
      expect(restored[0].blocks[0].kind, DayBlockKind.arrival);
      expect(restored[0].blocks[1].minutes, 45);
      expect(restored[1].name, 'Field trip');
    });

    test('a block energy round-trips; null energy is omitted', () {
      const t = DayTemplate(
        id: 'e',
        name: 'E',
        startMinute: 900,
        endMinute: 960,
        blocks: [
          DayBlock(
            id: 'x',
            label: 'Tuned',
            minutes: 30,
            kind: DayBlockKind.activity,
            energy: 0.9,
          ),
          DayBlock(
            id: 'y',
            label: 'Default',
            minutes: 30,
            kind: DayBlockKind.activity,
          ),
        ],
      );
      final restored = decodeDayTemplates(encodeDayTemplates([t])).single;
      expect(restored.blocks[0].energy, 0.9);
      expect(restored.blocks[1].energy, isNull);
    });

    test('decode is null/garbage safe', () {
      expect(decodeDayTemplates(null), isEmpty);
      expect(decodeDayTemplates(''), isEmpty);
      expect(decodeDayTemplates('not json'), isEmpty);
      expect(decodeDayTemplates('{"not":"a list"}'), isEmpty);
    });

    test('unknown block kind falls back to activity', () {
      expect(DayBlockKind.fromName('nonsense'), DayBlockKind.activity);
      expect(DayBlockKind.fromName(null), DayBlockKind.activity);
      expect(DayBlockKind.fromName('outdoor'), DayBlockKind.outdoor);
    });
  });

  group('starter template', () {
    test('is a sane, non-empty afternoon', () {
      final t = DayTemplate.starter(name: 'Regular day');
      expect(t.name, 'Regular day');
      expect(t.blocks, isNotEmpty);
      expect(t.startMinute, lessThan(t.endMinute));
      // Block ids are unique.
      final ids = t.blocks.map((b) => b.id).toSet();
      expect(ids.length, t.blocks.length);
    });
  });
}
