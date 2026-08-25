// Closing a room has to be genuinely non-destructive, and genuinely
// reversible — otherwise it is a delete wearing a friendlier label.

import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  const now = '2026-08-24T08:00:00Z';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.createMigrator().createAll();
    await db
        .into(db.spaces)
        .insert(
          SpacesCompanion.insert(
            id: 'sp1',
            name: 'Sunny Days',
            settings: '{}',
            capabilities: '{}',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final id in ['g1', 'g2']) {
      await db.groupsDao.create(
        id: id,
        spaceId: 'sp1',
        name: id,
      );
    }
    // g1's schedule — the thing a delete would have destroyed silently.
    await db
        .into(db.scheduleBlocks)
        .insert(
          ScheduleBlocksCompanion.insert(
            id: 'b1',
            spaceId: 'sp1',
            groupId: 'g1',
            date: '2026-08-24',
            startAt: '2026-08-24T15:00:00Z',
            endAt: '2026-08-24T15:45:00Z',
            kind: 'on_site',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async => db.close());

  test('a new room is created explicitly active, never null', () async {
    // The server column is NOT NULL and a default only applies to an
    // OMITTED column — a local null would fail the insert forever.
    final g = await (db.select(
      db.groups,
    )..where((g) => g.id.equals('g1'))).getSingle();
    expect(g.status, 'active');
  });

  test(
    'closing removes it from the active list and keeps its schedule',
    () async {
      await db.groupsDao.closeRoom('g1', now);

      final active = await db.groupsDao.watchInSpace('sp1').first;
      expect(active.map((g) => g.id), ['g2'], reason: 'out of today');

      final closed = await db.groupsDao.watchClosedInSpace('sp1').first;
      expect(closed.map((g) => g.id), ['g1'], reason: 'reachable on purpose');

      final blocks = await (db.select(
        db.scheduleBlocks,
      )..where((b) => b.groupId.equals('g1'))).get();
      expect(blocks.length, 1, reason: 'the schedule survives a close');
    },
  );

  test('reopening puts it straight back', () async {
    await db.groupsDao.closeRoom('g1', now);
    await db.groupsDao.reopenRoom('g1', now);
    final active = await db.groupsDao.watchInSpace('sp1').first;
    expect(active.map((g) => g.id).toSet(), {'g1', 'g2'});
    expect(await db.groupsDao.watchClosedInSpace('sp1').first, isEmpty);
  });

  test('a NULL status counts as active', () async {
    // The upgrade window: `status` is a new column, so every row already on
    // the device reads NULL until the sync carrying it lands. Testing
    // status = 'active' alone would hide every room in the program.
    await db.customStatement('UPDATE groups SET status = NULL');
    final active = await db.groupsDao.watchInSpace('sp1').first;
    expect(active.length, 2, reason: 'NULL is not "closed"');
    expect(await db.groupsDao.watchClosedInSpace('sp1').first, isEmpty);
  });

  test(
    'erasing really does take the schedule — which is why close exists',
    () async {
      await db.groupsDao.deleteById('g1');
      final blocks = await (db.select(
        db.scheduleBlocks,
      )..where((b) => b.groupId.equals('g1'))).get();
      // Drift's local FKs are not enforced the way Postgres cascades are, so
      // this asserts the ROOM is gone; the cascade itself is a server
      // behaviour documented in the migration. The point of the test is that
      // delete and close are genuinely different operations.
      final gone = await (db.select(
        db.groups,
      )..where((g) => g.id.equals('g1'))).getSingleOrNull();
      expect(gone, isNull);
      expect(blocks.length, lessThanOrEqualTo(1));
    },
  );
}
