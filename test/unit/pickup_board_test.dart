// Pins the Pickup board assembly (docs/WORKFLOWS.md gap #2): who's still
// here vs released, today-only departures, latest-wins, and the load-
// bearing invariant that releasing a child is a SEPARATE axis from
// attendance (computePickupBoard only ever READS attendance).

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/pickup/pickup_board_providers.dart';
import 'package:flutter_test/flutter_test.dart';

const _space = 'space-1';

Group _group(String id, String name) => Group(
  id: id,
  spaceId: _space,
  name: name,
  capabilities: '{}',
  createdAt: '2026-06-06T00:00:00Z',
  updatedAt: '2026-06-06T00:00:00Z',
);

Subject _subject(String id, String first, String last) => Subject(
  id: id,
  spaceId: _space,
  firstName: first,
  lastName: last,
  capabilities: '{}',
  createdAt: '2026-06-06T00:00:00Z',
  updatedAt: '2026-06-06T00:00:00Z',
);

AttendanceRecord _att(String subjectId, String status) => AttendanceRecord(
  id: 'att-$subjectId',
  spaceId: _space,
  subjectId: subjectId,
  date: '2026-06-06',
  status: status,
  recordedBy: 'm1',
  recordedAt: '2026-06-06T15:00:00Z',
  updatedAt: '2026-06-06T15:00:00Z',
);

Entry _departure(String subjectId, {required String at, String? to}) => Entry(
  id: 'dep-$subjectId-$at',
  spaceId: _space,
  kind: 'departure',
  details: '{}',
  recordedBy: 'm1',
  recordedAt: at,
  updatedAt: at,
  subjectId: subjectId,
  body: to,
);

void main() {
  // Local 4:00pm and 5:00pm on the "today" date used by the fixtures.
  const today = '2026-06-06';
  String at(int h, int m) =>
      DateTime(2026, 6, 6, h, m).toUtc().toIso8601String();

  group('computePickupBoard', () {
    test('present + late are here; absent/excused never appear', () {
      final g = _group('g1', 'Otters');
      final board = computePickupBoard(
        groups: [g],
        subjectsByGroup: {
          'g1': [
            _subject('s1', 'Amy', 'A'),
            _subject('s2', 'Ben', 'B'),
            _subject('s3', 'Cal', 'C'),
            _subject('s4', 'Dot', 'D'),
          ],
        },
        recordsByGroup: {
          'g1': [
            _att('s1', 'present'),
            _att('s2', 'late'),
            _att('s3', 'absent'),
            _att('s4', 'excused'),
          ],
        },
        departures: const [],
        today: today,
      );
      expect(board.stillHere.map((e) => e.subject.id), ['s1', 's2']);
      expect(board.released, isEmpty);
    });

    test('early_pickup shows as released (leftEarly), never vanishes', () {
      final board = computePickupBoard(
        groups: [_group('g1', 'Otters')],
        subjectsByGroup: {
          'g1': [_subject('s1', 'Amy', 'A'), _subject('s2', 'Ben', 'B')],
        },
        recordsByGroup: {
          'g1': [_att('s1', 'present'), _att('s2', 'early_pickup')],
        },
        departures: const [],
        today: today,
      );
      expect(board.stillHere.map((e) => e.subject.id), ['s1']);
      expect(board.released.map((e) => e.subject.id), ['s2']);
      final early = board.released.single;
      expect(early.leftEarly, isTrue);
      expect(early.departure, isNull); // no entry → no Undo
    });

    test('a departure today moves a child from here to released', () {
      final board = computePickupBoard(
        groups: [_group('g1', 'Otters')],
        subjectsByGroup: {
          'g1': [_subject('s1', 'Amy', 'A'), _subject('s2', 'Ben', 'B')],
        },
        recordsByGroup: {
          'g1': [_att('s1', 'present'), _att('s2', 'present')],
        },
        departures: [_departure('s2', at: at(17, 0), to: 'Grandma')],
        today: today,
      );
      expect(board.stillHere.map((e) => e.subject.id), ['s1']);
      expect(board.released.map((e) => e.subject.id), ['s2']);
      expect(board.released.single.departure!.body, 'Grandma');
      expect(board.hereCount, 1);
      expect(board.releasedCount, 1);
    });

    test('a departure from another day is ignored', () {
      final board = computePickupBoard(
        groups: [_group('g1', 'Otters')],
        subjectsByGroup: {
          'g1': [_subject('s1', 'Amy', 'A')],
        },
        recordsByGroup: {
          'g1': [_att('s1', 'present')],
        },
        departures: [
          _departure('s1', at: '2026-06-05T17:00:00Z', to: 'Yesterday'),
        ],
        today: today,
      );
      expect(board.stillHere.map((e) => e.subject.id), ['s1']);
      expect(board.released, isEmpty);
    });

    test('latest departure today wins (re-release after an undo+redo)', () {
      final board = computePickupBoard(
        groups: [_group('g1', 'Otters')],
        subjectsByGroup: {
          'g1': [_subject('s1', 'Amy', 'A')],
        },
        recordsByGroup: {
          'g1': [_att('s1', 'present')],
        },
        departures: [
          _departure('s1', at: at(16, 0), to: 'Dad'),
          _departure('s1', at: at(17, 30), to: 'Mom'),
        ],
        today: today,
      );
      expect(board.released.single.departure!.body, 'Mom');
    });

    test('still-here sorts by cohort then name; released by most-recent', () {
      final board = computePickupBoard(
        groups: [_group('g2', 'Zebras'), _group('g1', 'Otters')],
        subjectsByGroup: {
          'g1': [_subject('s2', 'Zoe', 'Z'), _subject('s1', 'Ann', 'A')],
          'g2': [_subject('s3', 'Mia', 'M'), _subject('s4', 'Eli', 'E')],
        },
        recordsByGroup: {
          'g1': [_att('s1', 'present'), _att('s2', 'present')],
          'g2': [_att('s3', 'present'), _att('s4', 'present')],
        },
        departures: [
          _departure('s4', at: at(16, 0)),
          _departure('s3', at: at(17, 0)),
        ],
        today: today,
      );
      // Otters before Zebras (cohort), Ann before Zoe (name).
      expect(board.stillHere.map((e) => e.subject.id), ['s1', 's2']);
      // s3 released at 5:00 is more recent than s4 at 4:00.
      expect(board.released.map((e) => e.subject.id), ['s3', 's4']);
    });

    test('groups missing from the maps are skipped (progressive load)', () {
      final board = computePickupBoard(
        groups: [_group('g1', 'Otters'), _group('g2', 'Zebras')],
        subjectsByGroup: {
          'g1': [_subject('s1', 'Amy', 'A')],
          // g2 absent — its streams haven't delivered.
        },
        recordsByGroup: {
          'g1': [_att('s1', 'present')],
        },
        departures: const [],
        today: today,
      );
      expect(board.stillHere.map((e) => e.subject.id), ['s1']);
      expect(board.isEmpty, isFalse);
    });
  });
}
