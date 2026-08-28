// The sandbox exists so a director can see what a role's Monday actually
// looks like — role preview gives permissions but keeps YOUR room
// assignments, so previewing as a counselor usually shows an empty room
// list. Here the membership is real too.
//
// The property that makes it safe to hand to anyone: it runs on a DETACHED
// database with no connector, so a pretend child cannot reach a real
// roster. These tests pin the seed, and pin that the pretend staff are
// genuinely assigned to rooms — which is the whole difference from preview.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/sandbox/sandbox_data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
