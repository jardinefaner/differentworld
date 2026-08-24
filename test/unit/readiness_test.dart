// The readiness briefing's whole value is that it disappears. These tests
// pin both halves: it names the right gaps, and it says nothing when there
// aren't any.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/readiness/readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const now = '2026-08-24T08:00:00Z';

  Subject kid(
    String id, {
    String? photo,
    String? allergies,
    bool? consent,
    String status = 'enrolled',
    String? groupId,
  }) => Subject(
    id: id,
    spaceId: 'sp1',
    firstName: id.toUpperCase(),
    lastName: 'X',
    status: status,
    capabilities: consent == null ? '{}' : '{"photo_consent":$consent}',
    createdAt: now,
    updatedAt: now,
    photoUrl: photo,
    allergies: allergies,
    groupId: groupId,
  );

  Group room(String id, String name) => Group(
    id: id,
    spaceId: 'sp1',
    name: name,
    capabilities: '{}',
    createdAt: now,
    updatedAt: now,
  );

  List<ReadinessItem> run({
    required List<Subject> roster,
    Set<String> withGuardian = const {},
    bool defaultAllows = true,
    List<Group> groups = const [],
    Set<String> arranged = const {},
  }) => computeReadiness(
    roster: roster,
    subjectIdsWithGuardian: withGuardian,
    spaceDefaultAllowsPhotos: defaultAllows,
    groups: groups,
    arrangedGroupIds: arranged,
  );

  test('a complete roster produces NOTHING', () {
    final items = run(
      roster: [
        kid('a', photo: 'p.jpg', allergies: 'None', consent: true),
        kid('b', photo: 'p.jpg', allergies: 'Peanuts', consent: false),
      ],
      withGuardian: {'a', 'b'},
    );
    expect(items, isEmpty, reason: 'nothing to do means nothing on screen');
  });

  test('the unreachable child is named first', () {
    final items = run(
      roster: [kid('a', photo: 'p.jpg', allergies: 'None', consent: true)],
    );
    expect(items.first.kind, ReadinessKind.missingGuardian);
  });

  test('it names people rather than counting them', () {
    final items = run(
      roster: [for (var i = 0; i < 6; i++) kid('k$i', consent: true)],
      withGuardian: {for (var i = 0; i < 6; i++) 'k$i'},
    );
    final photos = items.firstWhere(
      (i) => i.kind == ReadinessKind.missingPhoto,
    );
    expect(photos.count, 6);
    expect(photos.names.length, 3, reason: 'a sample, not a wall of names');
  });

  test('a child nobody may photograph is not "missing a photo"', () {
    final items = run(
      roster: [kid('a', allergies: 'None', consent: false)],
      withGuardian: {'a'},
    );
    expect(
      items.any((i) => i.kind == ReadinessKind.missingPhoto),
      isFalse,
      reason: 'asking for it would mean breaking the family’s answer',
    );
  });

  test('blank allergies is a question, not an answer', () {
    final items = run(
      roster: [kid('a', photo: 'p.jpg', consent: true)],
      withGuardian: {'a'},
    );
    expect(
      items.any((i) => i.kind == ReadinessKind.missingAllergyAnswer),
      isTrue,
    );
    // Typing "None" is what closes it.
    final after = run(
      roster: [kid('a', photo: 'p.jpg', allergies: 'None', consent: true)],
      withGuardian: {'a'},
    );
    expect(
      after.any((i) => i.kind == ReadinessKind.missingAllergyAnswer),
      isFalse,
    );
  });

  test('unanswered consent is surfaced without blocking anything', () {
    final items = run(
      roster: [kid('a', photo: 'p.jpg', allergies: 'None')],
      withGuardian: {'a'},
    );
    expect(items.single.kind, ReadinessKind.missingConsent);
  });

  test('alumni are not today’s problem', () {
    final items = run(roster: [kid('old', status: 'alumni')]);
    expect(items, isEmpty);
  });

  test('a cohort that has never been arranged is offered its first round', () {
    final items = run(
      roster: [
        kid(
          'a',
          photo: 'p.jpg',
          allergies: 'None',
          consent: true,
          groupId: 'g1',
        ),
        kid(
          'b',
          photo: 'p.jpg',
          allergies: 'None',
          consent: true,
          groupId: 'g1',
        ),
      ],
      withGuardian: {'a', 'b'},
      groups: [room('g1', 'Sparrows'), room('g2', 'Ospreys')],
    );
    // Only the cohort that actually has children in it.
    expect(items.length, 1);
    expect(items.single.kind, ReadinessKind.neverArranged);
    expect(items.single.groupName, 'Sparrows');
    expect(items.single.count, 2);
  });

  test('an already-arranged cohort stops asking', () {
    final items = run(
      roster: [
        kid(
          'a',
          photo: 'p.jpg',
          allergies: 'None',
          consent: true,
          groupId: 'g1',
        ),
      ],
      withGuardian: {'a'},
      groups: [room('g1', 'Sparrows')],
      arranged: {'g1'},
    );
    expect(items, isEmpty);
  });
}
