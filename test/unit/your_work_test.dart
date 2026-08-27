// "What you can do" is DERIVED from the same getters the gates read. That
// is the whole safety property: a hand-authored per-role list would drift
// into promising something the app then refuses, and the person it misled
// would be the newcomer who trusted it.
//
// These pin the three states, and that only OPEN items carry a route —
// sending someone into a screen that will refuse them is the dead end this
// surface exists to remove.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/roles/your_work.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const now = '2026-08-26T08:00:00Z';

  Viewer person({String role = 'teacher', String caps = '{}'}) => Viewer(
    member: Member(
      id: 'm1',
      displayName: 'Jordan',
      role: role,
      capabilities: caps,
      createdAt: now,
      updatedAt: now,
      spaceId: 'sp1',
    ),
    space: null,
  );

  List<WorkItem> flat(Viewer v) => [
    for (final g in workFor(v, primaryGroupId: 'g1')) ...g.items,
  ];

  WorkItem find(Viewer v, String label) =>
      flat(v).firstWhere((i) => i.label == label);

  group('the safety property', () {
    test('a blocked item NEVER carries a route', () {
      // If this ever fails, the screen is offering a tap into a NoAccess
      // wall, which is worse than showing nothing.
      for (final v in [
        person(),
        person(role: 'director'),
        person(role: 'kitchen'),
        const Viewer.empty(),
      ]) {
        for (final item in flat(v)) {
          if (!item.open) {
            expect(
              item.route,
              isNull,
              reason: '"${item.label}" is blocked but offers a route',
            );
          }
        }
      }
    });

    test('every blocked item explains itself', () {
      // Silence is what this surface exists to end.
      for (final item in flat(person(role: 'kitchen'))) {
        if (!item.open) expect(item.note, isNotNull);
      }
    });
  });

  group('the three states', () {
    test('a director can do the program-wide things', () {
      final v = person(role: 'director');
      expect(find(v, 'Add rooms, places and vehicles').open, isTrue);
      expect(find(v, 'Invite a teammate').open, isTrue);
    });

    test('a counselor is blocked from those, and told who to ask', () {
      final v = person();
      final item = find(v, 'Invite a teammate');
      expect(item.open, isFalse);
      expect(item.kind, WorkKind.needsSomeone);
      expect(item.note, contains('Program managers'));
    });

    test('cert blocks are a NEXT STEP, not a wall — even for a director', () {
      // The distinction the whole design rests on. Medication ships false
      // for every role including the Program Manager, but it is the ONE
      // kind of block a person clears themselves.
      final item = find(person(role: 'director'), 'Give medication');
      expect(item.open, isFalse);
      expect(item.kind, WorkKind.needsCert);
      expect(item.note, contains('certificate'));
      expect(item.kind, isNot(WorkKind.needsSomeone));
    });

    test('a granted cert flips it open', () {
      final v = person(caps: '{"can_administer_medication":true}');
      expect(find(v, 'Give medication').open, isTrue);
    });
  });

  group('the summary line', () {
    test('names the fixable count when there is one', () {
      expect(workSummary(workFor(person())), contains('could unlock'));
    });

    test('a viewer with nothing open still gets a coherent line', () {
      final line = workSummary(workFor(const Viewer.empty()));
      expect(line, startsWith('0 things you can do'));
    });
  });

  group('routes are concrete', () {
    test('room routes use the room when there is one', () {
      final v = person(role: 'director');
      expect(find(v, 'Take attendance').route, '/groups/g1/attendance');
    });

    test('and fall back to a program-wide route when there is not', () {
      final items = [
        for (final g in workFor(person(role: 'director'))) ...g.items,
      ];
      final att = items.firstWhere((i) => i.label == 'Take attendance');
      expect(att.route, '/checklist');
    });
  });
}
