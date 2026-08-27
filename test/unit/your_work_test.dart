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

  group('every row points somewhere real', () {
    // The bug this caught: the list offered "Record a meal" and "Give
    // medication" for capabilities with NO route, NO screen and NO feature
    // folder anywhere in the app. Promising work the app cannot do is
    // worse than a wrong link — it is a lie a newcomer has no way to check.
    //
    // The routes are checked against a literal list rather than the router
    // because the router needs a built app; keep this in sync when a route
    // moves, and a MISS here means a real dead tap.
    const realRoutes = {
      '/checklist',
      '/observations',
      '/captures/new',
      '/schedule',
      '/pickup',
      '/runbook',
      '/groups/new',
      '/settings/locations',
      '/settings/team/invite/new',
      '/vehicles',
    };

    test('no row invents a destination', () {
      for (final item in flat(person(role: 'director'))) {
        final r = item.route;
        if (r == null) continue;
        final ok = r.startsWith('/groups/g1/') || realRoutes.contains(r);
        expect(ok, isTrue, reason: '"${item.label}" points at $r');
      }
    });

    test('every row explains the moment it belongs to', () {
      // A row that cannot describe its journey is a capability key wearing
      // a button — which is exactly what the two removed rows were.
      for (final item in flat(person(role: 'director'))) {
        expect(item.journey, isNotNull, reason: item.label);
        expect(item.journey, isNotEmpty, reason: item.label);
      }
    });

    test('unimplemented capabilities are absent, not shown as blocked', () {
      final labels = flat(person(role: 'director')).map((i) => i.label);
      expect(labels, isNot(contains('Record a meal')));
      expect(labels, isNot(contains('Give medication')));
    });
  });

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
      expect(find(v, 'Add a room').open, isTrue);
      expect(find(v, 'Add a place').open, isTrue);
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
      // The distinction the whole design rests on. Driving ships false for
      // every role including the Program Manager, and it is the ONE kind of
      // block a person clears themselves.
      final item = find(person(role: 'director'), 'Drive program vehicles');
      expect(item.open, isFalse);
      expect(item.kind, WorkKind.needsCert);
      expect(item.note, contains('licence'));
      expect(item.kind, isNot(WorkKind.needsSomeone));
    });

    test('a granted cert flips it open', () {
      final v = person(caps: '{"can_drive":true}');
      expect(find(v, 'Drive program vehicles').open, isTrue);
    });
  });

  group('the summary line', () {
    test('names the fixable count when there is one', () {
      expect(workSummary(workFor(person())), contains('could unlock'));
    });

    test('a signed-out viewer has no work at all', () {
      final line = workSummary(workFor(const Viewer.empty()));
      expect(line, startsWith('0 things you can do'));
    });

    test('room work disappears when there is no room', () {
      // Not "shown and dead" — absent. A person with no cohort cannot pick
      // a child from it, and offering the row would be a tap into nothing.
      final noRoom = [for (final g in workFor(person())) ...g.items];
      expect(
        noRoom.map((i) => i.label),
        isNot(contains('Pick someone fairly')),
      );
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
