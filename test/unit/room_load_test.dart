// Ratio and capacity are the numbers an inspector asks about, so the
// arithmetic is pinned rather than eyeballed — especially the ceiling
// division, which is where "1.6 adults" quietly becomes "1".

import 'package:differentworld/features/rooms/room_load.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RoomLoad load({
    int children = 0,
    int staff = 0,
    int? capacity,
    int? ratio,
  }) => RoomLoad(
    childrenPresent: children,
    staffAssigned: staff,
    licensedCapacity: capacity,
    ratioChildrenPerAdult: ratio,
  );

  group('when nothing is set', () {
    test('the room is unchecked, not unlimited', () {
      final l = load(children: 200);
      expect(l.unchecked, isTrue);
      expect(l.overCapacity, isFalse);
      expect(l.understaffed, isFalse);
      expect(l.breached, isFalse);
      expect(l.roomFor, isNull, reason: 'no answer, rather than a wrong one');
    });

    test('a zero is treated as unset, not as a limit of zero', () {
      final l = load(children: 5, capacity: 0, ratio: 0);
      expect(l.unchecked, isTrue);
      expect(l.overCapacity, isFalse);
    });
  });

  group('capacity', () {
    test('at the limit is fine; one over is not', () {
      expect(load(children: 20, capacity: 20).overCapacity, isFalse);
      expect(load(children: 21, capacity: 20).overCapacity, isTrue);
    });
  });

  group('ratio', () {
    test('rounds UP — 13 children at 1:8 needs two adults, not 1.6', () {
      final l = load(children: 13, staff: 1, ratio: 8);
      expect(l.staffRequired, 2);
      expect(l.understaffed, isTrue);
      expect(l.staffShort, 1);
    });

    test('an exact multiple needs exactly that many', () {
      expect(load(children: 16, staff: 2, ratio: 8).staffRequired, 2);
      expect(load(children: 16, staff: 2, ratio: 8).understaffed, isFalse);
    });

    test('an empty room is not understaffed', () {
      final l = load(ratio: 8);
      expect(l.staffRequired, 0);
      expect(l.understaffed, isFalse);
    });

    test('more staff than needed is never a breach', () {
      final l = load(children: 4, staff: 5, ratio: 8);
      expect(l.understaffed, isFalse);
      expect(l.staffShort, isNull);
    });
  });

  group('room for one more', () {
    test('takes the TIGHTER of capacity and ratio', () {
      // Capacity says 6 spare; the ratio says only 2 (2 adults × 8 = 16).
      final l = load(children: 14, staff: 2, capacity: 20, ratio: 8);
      expect(l.roomFor, 2);
    });

    test('never goes negative — a full room has room for none', () {
      final l = load(children: 25, staff: 1, capacity: 20, ratio: 8);
      expect(l.roomFor, 0);
      expect(l.breached, isTrue);
    });

    test('one rule alone still answers', () {
      expect(load(children: 5, capacity: 12).roomFor, 7);
      expect(load(children: 5, staff: 2, ratio: 8).roomFor, 11);
    });
  });

  test('breached is either rule, not both', () {
    expect(
      load(children: 21, staff: 9, capacity: 20, ratio: 8).breached,
      isTrue,
    );
    expect(
      load(children: 19, staff: 1, capacity: 20, ratio: 8).breached,
      isTrue,
    );
    expect(
      load(children: 8, staff: 1, capacity: 20, ratio: 8).breached,
      isFalse,
    );
  });
}
