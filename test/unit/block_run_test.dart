import 'package:differentworld/features/action_words/block_run.dart';
import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_test/flutter_test.dart';

BlockRunInput _blk({
  String id = 'b1',
  String title = 'Block',
  String start = '2026-06-28T09:00:00.000Z',
  String end = '2026-06-28T09:45:00.000Z',
  String kind = 'on_site',
  String? notes,
  String? sessionSlug,
  String? status,
}) => (
  blockId: id,
  title: title,
  startAt: start,
  endAt: end,
  kind: kind,
  notes: notes,
  sessionSlug: sessionSlug,
  status: status,
);

void main() {
  group('buildBlockRun', () {
    test('orders by start time; maps title, time label, and duration', () {
      final beats = buildBlockRun([
        _blk(
          title: 'Snack',
          start: '2026-06-28T16:15:00.000Z',
          end: '2026-06-28T16:35:00.000Z',
        ),
        _blk(
          title: 'Arrival',
          start: '2026-06-28T15:30:00.000Z',
          end: '2026-06-28T16:15:00.000Z',
        ),
      ]);

      expect(beats.map((b) => b.big).toList(), ['Arrival', 'Snack']);

      final s = DateTime.parse('2026-06-28T15:30:00.000Z').toLocal();
      final e = DateTime.parse('2026-06-28T16:15:00.000Z').toLocal();
      expect(beats.first.label, '${timeOfDay(s)} – ${timeOfDay(e)}');
      expect(beats.first.suggestedSeconds, 45 * 60);
      expect(beats.first.kind, DayBeatKind.activity);
    });

    test('drops skipped and cancelled blocks', () {
      final beats = buildBlockRun([
        _blk(title: 'Run', status: 'planned'),
        _blk(title: 'Skip', status: 'skipped'),
        _blk(title: 'Cancel', status: 'cancelled'),
        _blk(title: 'AlsoRun'),
      ]);

      final titles = beats.map((b) => b.big).toList();
      expect(titles, containsAll(<String>['Run', 'AlsoRun']));
      expect(titles, isNot(contains('Skip')));
      expect(titles, isNot(contains('Cancel')));
      expect(beats.length, 2);
    });

    test('a closed block becomes the close beat; everything else is activity', () {
      final beats = buildBlockRun([
        _blk(
          title: 'Make',
          start: '2026-06-28T15:00:00.000Z',
          end: '2026-06-28T15:30:00.000Z',
        ),
        _blk(
          title: 'Trip',
          kind: 'field_trip',
          start: '2026-06-28T16:00:00.000Z',
          end: '2026-06-28T17:00:00.000Z',
        ),
        _blk(
          title: 'Pickup',
          kind: 'closed',
          start: '2026-06-28T18:00:00.000Z',
          end: '2026-06-28T18:30:00.000Z',
        ),
      ]);

      expect(beats.map((b) => b.kind).toList(), [
        DayBeatKind.activity, // Make
        DayBeatKind.activity, // Trip (field_trip still runs as a do-it beat)
        DayBeatKind.close, // Pickup (closed → the handoff)
      ]);
    });

    test('a session slug flags a runnable session; none leaves lines empty', () {
      final beats = buildBlockRun([
        _blk(title: 'Photo', sessionSlug: 'photo-s1'),
        _blk(title: 'Plain'),
      ]);

      expect(beats.firstWhere((b) => b.big == 'Photo').lines, isNotEmpty);
      expect(beats.firstWhere((b) => b.big == 'Plain').lines, isEmpty);
    });

    test('empty title falls back; malformed dates do not crash', () {
      final beats = buildBlockRun([
        _blk(title: '   ', start: 'not-a-date', end: 'also-bad'),
      ]);

      expect(beats.single.big, 'Untitled block');
      expect(beats.single.label, '');
      expect(beats.single.suggestedSeconds, 0);
    });

    test('empty schedule yields an empty run', () {
      expect(buildBlockRun(const []), isEmpty);
    });

    test('buildBlockRunAligned aligns beats with source blocks (drops + sorts)', () {
      final inputs = [
        _blk(
          id: 'late',
          title: 'Late',
          start: '2026-06-28T17:00:00.000Z',
          end: '2026-06-28T17:30:00.000Z',
        ),
        _blk(id: 'skip', title: 'Skip', status: 'skipped'),
        _blk(
          id: 'early',
          title: 'Early',
          start: '2026-06-28T15:00:00.000Z',
          end: '2026-06-28T15:30:00.000Z',
        ),
      ];
      final run = buildBlockRunAligned(inputs);

      expect(run.ordered.map((b) => b.blockId).toList(), ['early', 'late']);
      expect(run.beats.length, run.ordered.length);
      for (var i = 0; i < run.beats.length; i++) {
        expect(run.beats[i].big, run.ordered[i].title);
      }
    });

    test('liveBlockOrder is deterministic for equal start times (blockId tiebreak)', () {
      final inputs = [
        _blk(id: 'z', title: 'Z'),
        _blk(id: 'a', title: 'A'),
        _blk(id: 'm', title: 'M'),
      ];
      // All share the default start; the blockId tiebreaker gives a stable order.
      expect(liveBlockOrder(inputs).map((b) => b.blockId).toList(), [
        'a',
        'm',
        'z',
      ]);
    });

    test('energy is derived from kind + title (drives the arc)', () {
      double e(BlockRunInput b) => buildBlockRun([b]).single.energy;
      expect(e(_blk(kind: 'closed')), lessThan(0.3));
      expect(e(_blk(kind: 'field_trip')), greaterThan(0.8));
      expect(e(_blk(title: 'Free play outside')), greaterThan(0.8));
      expect(e(_blk(title: 'Morning circle')), lessThan(0.4));
      expect(e(_blk(title: 'Make a robot')), inInclusiveRange(0.5, 0.75));
    });
  });
}
