// Action-layer test harness (docs/EXTENDING.md "Action-layer test harness"):
// a real in-memory Drift DB so EntryActions runs end-to-end. Production opens
// AppDatabase over PowerSync (which owns the schema, so the migration is
// no-op); tests open it over NativeDatabase.memory() and materialize the
// schema themselves with createMigrator().createAll().
//
// First use: pin the snap-the-paper offline footgun — the attachment row MUST
// carry the SAME id passed to uploadOnly, or a deferred offline upload patches
// a non-existent row and the photo is silently lost (CLAUDE.md "Offline
// attachment uploads"). This test makes that contract executable.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = '2026-06-13T00:00:00Z';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.createMigrator().createAll();
    await db.into(db.spaces).insert(
          SpacesCompanion.insert(
            id: 'sp1',
            name: 'Test Program',
            settings: '{}',
            capabilities: '{}',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.members).insert(
          MembersCompanion.insert(
            id: 'm1',
            displayName: 'Tess',
            role: 'teacher',
            capabilities: '{}',
            createdAt: now,
            updatedAt: now,
            spaceId: const Value('sp1'),
          ),
        );
    final member =
        await (db.select(db.members)..where((t) => t.id.equals('m1'))).getSingle();
    final space =
        await (db.select(db.spaces)..where((t) => t.id.equals('sp1'))).getSingle();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        viewerProvider.overrideWithValue(Viewer(member: member, space: space)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('createWorkSample writes a work_sample entry + pins the attachment id',
      () async {
    final actions = container.read(entryActionsProvider);
    final entryId = await actions.createWorkSample(
      subjectId: 's1',
      groupId: 'g1',
      caption: 'Friday writing',
      photoUrls: ['sp1/attachment/ATT1/x.jpg'],
      photoIds: ['ATT1'],
      worldId: 'me',
      day: 5,
    );

    final entries = await db.entriesDao
        .watchForSubject(subjectId: 's1', kind: EntryKind.workSample)
        .first;
    expect(entries, hasLength(1));
    expect(entries.first.id, entryId);
    expect(entries.first.kind, EntryKind.workSample);

    // THE FOOTGUN: the attachment must carry the pinned id 'ATT1', so a
    // deferred offline upload's updateUrl('ATT1') patches THIS row.
    final atts = await db.attachmentsDao
        .watchFor(entityKind: 'entry', entityId: entryId)
        .first;
    expect(atts, hasLength(1));
    expect(atts.first.id, 'ATT1', reason: 'attachment id must be the pinned id');
    expect(atts.first.url, 'sp1/attachment/ATT1/x.jpg');
  });

  test('setWorkSampleInBook flips in_book, preserving world/day tags',
      () async {
    final actions = container.read(entryActionsProvider);
    final id = await actions.createWorkSample(
      subjectId: 's1',
      groupId: 'g1',
      worldId: 'me',
      day: 5,
    );
    final entry =
        await (db.select(db.entries)..where((e) => e.id.equals(id))).getSingle();

    await actions.setWorkSampleInBook(entry, inBook: true);

    final after =
        await (db.select(db.entries)..where((e) => e.id.equals(id))).getSingle();
    expect(after.details, contains('"in_book":true'));
    expect(after.details, contains('"world_id":"me"'));
    expect(after.details, contains('"day":5'));
  });
}
