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
import 'package:differentworld/features/heroes/hero_catalog.dart';
import 'package:differentworld/features/recap/recap_model.dart';
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
    await db
        .into(db.spaces)
        .insert(
          SpacesCompanion.insert(
            id: 'sp1',
            name: 'Test Program',
            settings: '{}',
            capabilities: '{}',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.members)
        .insert(
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
    final member = await (db.select(
      db.members,
    )..where((t) => t.id.equals('m1'))).getSingle();
    final space = await (db.select(
      db.spaces,
    )..where((t) => t.id.equals('sp1'))).getSingle();
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

  test(
    'createWorkSample writes a work_sample entry + pins the attachment id',
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
      expect(
        atts.first.id,
        'ATT1',
        reason: 'attachment id must be the pinned id',
      );
      expect(atts.first.url, 'sp1/attachment/ATT1/x.jpg');
    },
  );

  test(
    'setWorkSampleInBook flips in_book, preserving world/day tags',
    () async {
      final actions = container.read(entryActionsProvider);
      final id = await actions.createWorkSample(
        subjectId: 's1',
        groupId: 'g1',
        worldId: 'me',
        day: 5,
      );
      final entry = await (db.select(
        db.entries,
      )..where((e) => e.id.equals(id))).getSingle();

      await actions.setWorkSampleInBook(entry, inBook: true);

      final after = await (db.select(
        db.entries,
      )..where((e) => e.id.equals(id))).getSingle();
      expect(after.details, contains('"in_book":true'));
      expect(after.details, contains('"world_id":"me"'));
      expect(after.details, contains('"day":5'));
    },
  );

  // "Do It" — the accumulative genre (docs/VISION.md 2026-06-18). The whole
  // point vs the ephemeral games is that doing leaves a durable record, so
  // pin the persistence contract executable.
  test(
    'recordDidIt writes a did_it room record (group-scoped, no subject)',
    () async {
      final actions = container.read(entryActionsProvider);
      final id = await actions.recordDidIt(
        instruction: 'Build the tallest tower with what is on the table',
        verb: 'build',
        groupId: 'g1',
      );

      final rows = await (db.select(
        db.entries,
      )..where((e) => e.kind.equals(EntryKind.didIt))).get();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.id, id);
      expect(row.groupId, 'g1');
      expect(
        row.subjectId,
        isNull,
        reason: 'the room record carries no subject',
      );
      expect(row.details, contains('"instruction":'));
      expect(row.details, contains('"verb":"build"'));
      // `count` is omitted when null (the `'count': ?count` null-aware element) —
      // a stray "count":null would be a regression of that encoding.
      expect(row.details, isNot(contains('"count"')));
    },
  );

  test(
    'recordDidIt proof photo rides the room record + pins the attachment id',
    () async {
      final actions = container.read(entryActionsProvider);
      final id = await actions.recordDidIt(
        instruction: 'Find something blue and show a friend',
        verb: 'find',
        groupId: 'g1',
        photoUrls: ['sp1/attachment/PROOF1/x.jpg'],
        photoIds: ['PROOF1'],
      );

      // Same offline footgun as createWorkSample: the attachment id MUST equal
      // the uploadOnly entityId so a deferred offline upload patches THIS row.
      final atts = await db.attachmentsDao
          .watchFor(entityKind: 'entry', entityId: id)
          .first;
      expect(atts, hasLength(1));
      expect(
        atts.single.id,
        'PROOF1',
        reason: 'attachment id must be the pinned uploadOnly entityId',
      );
      expect(atts.single.url, 'sp1/attachment/PROOF1/x.jpg');
    },
  );

  test(
    'recordDidIt per-child tag writes a subject row with no proof photo',
    () async {
      final actions = container.read(entryActionsProvider);
      final id = await actions.recordDidIt(
        instruction: 'Help someone clean up',
        verb: 'help',
        groupId: 'g1',
        subjectId: 's1',
      );

      final row = await (db.select(
        db.entries,
      )..where((e) => e.id.equals(id))).getSingle();
      expect(row.subjectId, 's1');
      expect(row.kind, EntryKind.didIt);
      // Tagged-child entries are photo-less attributions — the proof rides only
      // the room record (one entry can carry it; see the footgun above).
      final atts = await db.attachmentsDao
          .watchFor(entityKind: 'entry', entityId: id)
          .first;
      expect(atts, isEmpty, reason: 'attribution rows carry no proof photo');
    },
  );

  // Heroes — the make-believe alter-ego (docs/VISION.md 2026-06-19). One
  // evolving row per child: recordHero UPSERTS, so re-saving must not duplicate.
  const luna = HeroDraft(
    animal: HeroPick('fox', 'Fox', '🦊'),
    skin: HeroPick('midnight', 'Midnight', '🌙'),
    powers: [HeroPick('invisible', 'Turns invisible', '🫥')],
    name: 'Luna',
    from: 'the Willow Woods',
  );

  test('recordHero creates one hero row carrying the draft', () async {
    final actions = container.read(entryActionsProvider);
    final id = await actions.recordHero(subjectId: 's1', draft: luna);

    final rows = await (db.select(
      db.entries,
    )..where((e) => e.kind.equals(EntryKind.hero))).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, id);
    expect(rows.single.subjectId, 's1');
    expect(rows.single.details, contains('"name":"Luna"'));
    expect(rows.single.details, contains('"from":"the Willow Woods"'));
    expect(rows.single.details, contains('"fox"'));
  });

  test(
    'recordHero upserts — re-saving evolves the same row, no duplicate',
    () async {
      final actions = container.read(entryActionsProvider);
      final first = await actions.recordHero(subjectId: 's1', draft: luna);
      const rex = HeroDraft(
        animal: HeroPick('wolf', 'Wolf', '🐺'),
        skin: HeroPick('storm', 'Storm', '⛈️'),
        powers: [
          HeroPick('speed', 'Super speed', '💨'),
          HeroPick('fly', 'Can fly', '🪽'),
        ],
        name: 'Rex',
        from: 'the Tall Mountains',
      );
      final second = await actions.recordHero(subjectId: 's1', draft: rex);

      expect(
        second,
        first,
        reason: 'same row id — upsert, not a second insert',
      );
      final rows = await (db.select(
        db.entries,
      )..where((e) => e.kind.equals(EntryKind.hero))).get();
      expect(rows, hasLength(1), reason: 'one evolving hero per child');
      expect(rows.single.details, contains('"name":"Rex"'));
      expect(rows.single.details, isNot(contains('Luna')));
    },
  );

  test('recordHero drawing attaches with the pinned uploadOnly id', () async {
    final actions = container.read(entryActionsProvider);
    final id = await actions.recordHero(
      subjectId: 's1',
      draft: luna,
      photoUrls: ['sp1/attachment/HERO1/x.jpg'],
      photoIds: ['HERO1'],
    );

    final atts = await db.attachmentsDao
        .watchFor(entityKind: 'entry', entityId: id)
        .first;
    expect(atts, hasLength(1));
    expect(
      atts.single.id,
      'HERO1',
      reason:
          'attachment id must be the pinned id so an offline upload patches '
          'this row',
    );
    expect(atts.single.url, 'sp1/attachment/HERO1/x.jpg');
  });

  // The Daily ritual (docs/VISION.md 2026-06-19) — a captured answer to a
  // prompt. Accumulative ("document the now"); the prompt is denormalized into
  // details so the record is self-contained.
  test(
    'recordDailyResponse writes a daily_response with the prompt + answer',
    () async {
      final actions = container.read(entryActionsProvider);
      final id = await actions.recordDailyResponse(
        promptKind: 'question',
        promptText: 'What would you invent?',
        subjectId: 's1',
        responseText: 'a robot that does homework',
      );

      final row = await (db.select(
        db.entries,
      )..where((e) => e.id.equals(id))).getSingle();
      expect(row.kind, EntryKind.dailyResponse);
      expect(
        row.subjectId,
        's1',
        reason: 'a child answer flows into their Book',
      );
      expect(row.body, 'a robot that does homework');
      expect(row.details, contains('"prompt_kind":"question"'));
      expect(row.details, contains('What would you invent?'));
    },
  );

  test('recordDailyResponse drawing attaches with the pinned id', () async {
    final actions = container.read(entryActionsProvider);
    final id = await actions.recordDailyResponse(
      promptKind: 'quote',
      promptText: 'The future belongs to the curious.',
      groupId: 'g1',
      photoUrls: ['sp1/attachment/DR1/x.jpg'],
      photoIds: ['DR1'],
    );

    final atts = await db.attachmentsDao
        .watchFor(entityKind: 'entry', entityId: id)
        .first;
    expect(atts, hasLength(1));
    expect(atts.single.id, 'DR1');
  });

  test('recordRecap writes one recap entry per child; re-send upserts', () async {
    final actions = container.read(entryActionsProvider);
    Future<List<Entry>> recapsFor(String subjectId) => db.entriesDao
        .watchForSubject(
          subjectId: subjectId,
          kind: EntryKind.recap,
          limit: 10,
        )
        .first;

    await actions.recordRecap(
      groupId: 'g1',
      date: '2026-06-19',
      activities: const ['PE', 'Potions'],
      question: 'What is happiness?',
      momentNote: 'We brewed potions',
      children: const [
        RecapChildInput(
          subjectId: 's1',
          firstName: 'Maya',
          ownNames: {'Maya'},
          answer: 'When we share',
        ),
        RecapChildInput(subjectId: 's2', firstName: 'Ari', ownNames: {'Ari'}),
      ],
    );

    // One recap row per child, each subject-scoped (rides the family path).
    expect(await recapsFor('s1'), hasLength(1));
    expect(await recapsFor('s2'), hasLength(1));
    final maya = (await recapsFor('s1')).single;
    expect(maya.subjectId, 's1');
    expect(maya.kind, EntryKind.recap);
    expect(maya.details, contains('When we share'));

    // Re-sending the SAME day updates in place — no duplicate.
    await actions.recordRecap(
      groupId: 'g1',
      date: '2026-06-19',
      activities: const ['PE', 'Potions', 'Letters'],
      children: const [
        RecapChildInput(subjectId: 's1', firstName: 'Maya', ownNames: {'Maya'}),
      ],
    );
    final after = await recapsFor('s1');
    expect(after, hasLength(1), reason: 'same-day re-send upserts');
    expect(after.single.details, contains('Letters'));
  });
}
