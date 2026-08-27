// The trim is a statement about what is PUT IN FRONT of a new teacher, never
// about what they are allowed to do. These tests pin the three promises that
// make that true — because the failure mode of a "simple mode" is that it
// quietly becomes a permissions system, and nobody notices until a teacher
// cannot reach something they need.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/widgets/nav_destinations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const now = '2026-08-25T08:00:00Z';

  Viewer director() => const Viewer(
    member: Member(
      id: 'm1',
      displayName: 'Dee',
      role: 'director',
      capabilities: '{}',
      createdAt: now,
      updatedAt: now,
      spaceId: 'sp1',
    ),
    space: Space(
      id: 'sp1',
      name: 'Program',
      capabilities: '{}',
      settings: '{}',
      createdAt: now,
      updatedAt: now,
    ),
  );

  test('off by default — an existing user keeps their whole app', () {
    final full = buildNavDestinations(director());
    final same = buildNavDestinations(director());
    expect(same.length, full.length);
    expect(full.length, greaterThan(10));
  });

  test('on, the menu is the essentials plus Settings and nothing else', () {
    final trimmed = buildNavDestinations(director(), startingSimple: true);
    expect(
      trimmed.map((d) => d.label).toList(),
      ['Today', 'Observations', 'Captures', 'Settings'],
    );
  });

  test('Settings always survives — the trim must be leaveable from in-app', () {
    final trimmed = buildNavDestinations(director(), startingSimple: true);
    expect(trimmed.any((d) => d.route == navFooterRoute), isTrue);
  });

  test('the trim only ever REMOVES — it can never add a destination', () {
    final full = buildNavDestinations(director()).map((d) => d.route).toSet();
    final trimmed = buildNavDestinations(director(), startingSimple: true);
    expect(trimmed.every((d) => full.contains(d.route)), isTrue);
  });

  test('capability gates still apply underneath the trim', () {
    // A viewer who cannot observe must not get Observations back just
    // because the trim marked it essential — essential is about salience,
    // onlyFor is about permission, and the permission wins.
    const noObserve = Viewer(
      member: Member(
        id: 'm2',
        displayName: 'Ass',
        role: 'assistant',
        capabilities: '{"can_observe":false}',
        createdAt: now,
        updatedAt: now,
        spaceId: 'sp1',
      ),
      space: null,
    );
    final trimmed = buildNavDestinations(noObserve, startingSimple: true);
    expect(trimmed.map((d) => d.label), isNot(contains('Observations')));
  });

  test('the layout still splits cleanly with almost nothing in it', () {
    final layout = buildNavLayout(director(), startingSimple: true);
    expect(layout.spine.map((d) => d.label), [
      'Today',
      'Observations',
      'Captures',
    ]);
    // Every group is emptied by the trim; none may render as a bare header.
    expect(layout.groups, isEmpty);
    expect(layout.footer.single.route, navFooterRoute);
  });

  test('exactly three destinations are marked essential', () {
    // A guard on the bar itself. The wall comes back one plausible item at
    // a time, so the count is pinned rather than left to judgment.
    final essential = buildNavDestinations(
      director(),
    ).where((d) => d.essential);
    expect(essential.length, 3);
  });
}
