// The sandbox exists so a director can see what a role's Monday actually
// looks like — role preview gives permissions but keeps YOUR room
// assignments, so previewing as a counselor usually shows an empty room
// list. Here the membership is real too.
//
// The property that makes it safe to hand to anyone: it runs on a DETACHED
// database with no connector, so a pretend child cannot reach a real
// roster. These tests pin the seed, and pin that the pretend staff are
// genuinely assigned to rooms — which is the whole difference from preview.

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/sandbox/sandbox_data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('day one', _dayOneTests);

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.detached(NativeDatabase.memory());
    await db.materializeSchema();
    await seedSandbox(db, nowIso: '2026-08-27T08:00:00Z');
  });

  tearDown(() async => db.close());

  test('a whole pretend program exists', () async {
    final rooms = await db.select(db.groups).get();
    final kids = await db.select(db.subjects).get();
    final staff = await db.select(db.members).get();
    expect(rooms, hasLength(2));
    expect(kids, hasLength(9));
    expect(staff, hasLength(sandboxStaff.length));
  });

  test('every pretend staffer with rooms is really assigned to them', () async {
    // The difference from role preview, and the reason this exists. If the
    // assignments were not real, a counselor here would see the same empty
    // room list that preview shows.
    final links = await db.select(db.groupMembers).get();
    for (final s in sandboxStaff) {
      final mine = links.where((l) => l.memberId == s.id).map((l) => l.groupId);
      expect(
        mine.toSet(),
        s.rooms.toSet(),
        reason: '${s.name} should be assigned to ${s.rooms}',
      );
    }
  });

  test('one staffer per previewable role, so every lens has a body', () async {
    final roles = sandboxStaff.map((s) => s.role).toSet();
    expect(
      roles,
      containsAll(['director', 'lead_teacher', 'teacher', 'specialist']),
    );
  });

  test(
    'rooms carry real limits, so the ratio bar has something true to say',
    () async {
      final rooms = await db.select(db.groups).get();
      for (final r in rooms) {
        expect(r.capabilities, contains('licensed_capacity'));
        expect(r.capabilities, contains('ratio_children_per_adult'));
      }
    },
  );

  test('every child sits in a room that exists', () async {
    final roomIds = (await db.select(db.groups).get()).map((g) => g.id).toSet();
    for (final k in await db.select(db.subjects).get()) {
      expect(roomIds, contains(k.groupId), reason: k.firstName);
    }
  });

  test('the sandbox space is its own, not a real one', () async {
    final spaces = await db.select(db.spaces).get();
    expect(spaces.single.id, sandboxSpaceId);
    expect(spaces.single.name, contains('sandbox'));
  });
}

// The day-one sandbox exists for a question the app otherwise cannot answer
// about itself: "what does someone who has never seen this land on?" A real
// program can never show it again, because the starter spine is gated on
// `onboarding_started` and that marker is only ever written when a space is
// CREATED. So these pin the two things that make the answer trustworthy —
// that day one is genuinely empty, and that it is spine-eligible for the same
// reason a real new program is.
void _dayOneTests() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.detached(NativeDatabase.memory());
    await db.materializeSchema();
    await seedSandbox(
      db,
      nowIso: '2026-08-27T08:00:00Z',
      day: SandboxDay.dayOne,
    );
  });

  tearDown(() async => db.close());

  test('day one has nothing set up yet', () async {
    final rooms = await db.select(db.groups).get();
    final staff = await db.select(db.members).get();
    expect(rooms, isEmpty, reason: 'a new program has no rooms');
    expect(
      staff.length,
      1,
      reason: 'a new program has exactly the director who made it',
    );
    expect(staff.single.role, 'director');
  });

  test('day one is spine-eligible, and for the real reason', () async {
    final space = await db.spacesDao.findById(sandboxSpaceId);
    expect(space, isNotNull);
    // Set by seedSampleChild — the SAME call the real create-space flow
    // makes. If this ever goes false the sandbox stops showing the first run
    // even though it still looks empty, which is the failure that would be
    // hardest to notice.
    expect(space!.caps.getBool(SpaceCaps.onboardingStarted), isTrue);
    expect(
      space.caps.getString(SpaceCaps.onboardingSampleSubjectId),
      isNotNull,
      reason: 'the spine points at Sam; without the id its card cannot open',
    );
  });

  test(
    'day one still has Sam, so the story card has something to show',
    () async {
      final kids = await db.select(db.subjects).get();
      expect(kids.length, 1);
      expect(kids.single.firstName, 'Sam');
      final entries = await db.select(db.entries).get();
      expect(entries, isNotEmpty, reason: "Sam's six weeks of moments");
    },
  );
}
