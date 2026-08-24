// The rollover's one promise is that a new intake costs no old child
// anything. These tests exist to make that promise executable — including
// an end-to-end pass against a real in-memory database asserting that every
// row attached to an alumnus survives.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/rollover/rollover_plan.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const roster = [
    RolloverCandidate(subjectId: 's1', name: 'Owen', currentGroupId: 'g1'),
    RolloverCandidate(subjectId: 's2', name: 'Ava', currentGroupId: 'g1'),
    RolloverCandidate(subjectId: 's3', name: 'Liam', currentGroupId: 'g2'),
  ];

  group('planning', () {
    test('the default is that nobody changes and nobody leaves', () {
      final plan = defaultPlan(roster);
      final s = summarise(roster, plan);
      expect(s.carriedForward, 3);
      expect(s.becameAlumni, 0);
      expect(s.movedRoom, 0);
      expect(s.recordsDeleted, 0);
    });

    test('silence means carry forward, never removal', () {
      // A child missing from the plan entirely must not be dropped.
      final s = summarise(roster, const {});
      expect(s.carriedForward, 3);
      expect(s.becameAlumni, 0);
    });

    test('moving a child up counts as a move, not a loss', () {
      final plan = {
        ...defaultPlan(roster),
        's1': const RolloverChoice(fate: Fate.carriesForward, groupId: 'g2'),
      };
      final s = summarise(roster, plan);
      expect(s.movedRoom, 1);
      expect(s.carriedForward, 3);
      expect(s.becameAlumni, 0);
    });

    test('alumni are counted separately and never deleted', () {
      final plan = {
        ...defaultPlan(roster),
        's3': const RolloverChoice(fate: Fate.becomesAlumni),
      };
      final s = summarise(roster, plan);
      expect(s.carriedForward, 2);
      expect(s.becameAlumni, 1);
      expect(s.recordsDeleted, 0);
    });

    test('returningRooms carries only the returners, resolving the room', () {
      final plan = {
        's1': const RolloverChoice(fate: Fate.carriesForward, groupId: 'g2'),
        's3': const RolloverChoice(fate: Fate.becomesAlumni),
      };
      final rooms = returningRooms(roster, plan);
      expect(rooms.keys.toSet(), {'s1', 's2'});
      expect(rooms['s1'], 'g2', reason: 'explicit move');
      expect(rooms['s2'], 'g1', reason: 'unlisted keeps their room');
      expect(rooms.containsKey('s3'), isFalse, reason: 'alumni are absent');
    });
  });

  group('naming the next period', () {
    test('bumps a school-year name', () {
      expect(suggestTermName('2025–26', DateTime(2026, 8, 24)), '2026–27');
    });

    test('bumps a session name', () {
      expect(
        suggestTermName('Summer 2025', DateTime(2026, 6, 4)),
        'Summer 2026',
      );
    });

    test('falls back to the school year that contains today', () {
      expect(suggestTermName(null, DateTime(2026, 8, 24)), '2026–27');
      expect(suggestTermName(null, DateTime(2026, 3, 2)), '2025–26');
    });
  });

  group('applied against a real database', () {
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
      for (final g in ['g1', 'g2']) {
        await db
            .into(db.groups)
            .insert(
              GroupsCompanion.insert(
                id: g,
                spaceId: 'sp1',
                name: g,
                capabilities: '{}',
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      for (final (id, first, group) in const [
        ('s1', 'Owen', 'g1'),
        ('s2', 'Ava', 'g1'),
        ('s3', 'Liam', 'g2'),
      ]) {
        await db
            .into(db.subjects)
            .insert(
              SubjectsCompanion.insert(
                id: id,
                spaceId: 'sp1',
                firstName: first,
                lastName: 'X',
                capabilities: '{}',
                createdAt: now,
                updatedAt: now,
                groupId: Value(group),
              ),
            );
      }
      // Liam's year: an observation, a photo tag and a character sheet. If
      // the rollover is additive, all three must still be here afterwards.
      await db
          .into(db.entries)
          .insert(
            EntriesCompanion.insert(
              id: 'e1',
              spaceId: 'sp1',
              kind: 'observation',
              details: '{}',
              recordedBy: 'm1',
              recordedAt: now,
              updatedAt: now,
              body: const Value('Liam built a tower'),
              subjectId: const Value('s3'),
            ),
          );
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'a1',
              spaceId: 'sp1',
              entityKind: 'entry',
              entityId: 'e1',
              url: 'attachments/a1.jpg',
              mimeType: 'image/jpeg',
              createdAt: now,
              updatedAt: now,
              subjectId: const Value('s3'),
            ),
          );
      await db
          .into(db.characterSheets)
          .insert(
            CharacterSheetsCompanion.insert(
              id: 'cs1',
              spaceId: 'sp1',
              subjectId: 's3',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() async => db.close());

    Future<void> roll(Map<String, String?> returning) async {
      var seq = 0;
      await db.enrollmentsDao.applyRollover(
        spaceId: 'sp1',
        newTermId: 't2',
        newTerm: TermsCompanion.insert(
          id: 't2',
          spaceId: 'sp1',
          name: '2026–27',
          startsOn: '2026-09-01',
          createdAt: now,
          updatedAt: now,
          isCurrent: const Value(1),
        ),
        returning: returning,
        newId: () => 'en${seq++}',
        nowIso: now,
      );
    }

    test(
      'carrying everyone forward opens an enrollment each, deletes nothing',
      () async {
        await roll({'s1': 'g1', 's2': 'g1', 's3': 'g2'});
        final rows = await db.select(db.enrollments).get();
        expect(rows.length, 3);
        expect(rows.every((e) => e.endedAt == null), isTrue);
        final kids = await db.select(db.subjects).get();
        expect(kids.length, 3);
        expect(kids.every((s) => s.status == 'enrolled'), isTrue);
      },
    );

    test('an alumnus keeps every record attached to them', () async {
      await roll({'s1': 'g1', 's2': 'g1'}); // s3 omitted → alumni

      final liam = await (db.select(
        db.subjects,
      )..where((s) => s.id.equals('s3'))).getSingle();
      expect(liam.status, 'alumni', reason: 'off the active roster');

      // The whole point: their year is untouched.
      final entries = await (db.select(
        db.entries,
      )..where((e) => e.subjectId.equals('s3'))).get();
      final photos = await (db.select(
        db.attachments,
      )..where((a) => a.subjectId.equals('s3'))).get();
      final sheet = await (db.select(
        db.characterSheets,
      )..where((c) => c.subjectId.equals('s3'))).get();
      expect(entries.length, 1, reason: 'observation survives');
      expect(photos.length, 1, reason: 'photo tag survives');
      expect(sheet.length, 1, reason: 'character sheet survives');
    });

    test('moving a child up updates their current room too', () async {
      await roll({'s1': 'g2', 's2': 'g1', 's3': 'g2'});
      final owen = await (db.select(
        db.subjects,
      )..where((s) => s.id.equals('s1'))).getSingle();
      expect(owen.groupId, 'g2');
      final enrollment = await (db.select(
        db.enrollments,
      )..where((e) => e.subjectId.equals('s1'))).getSingle();
      expect(enrollment.groupId, 'g2');
      expect(enrollment.termId, 't2');
    });

    test(
      'a second rollover closes the first period rather than dropping it',
      () async {
        await roll({'s1': 'g1', 's2': 'g1', 's3': 'g2'});
        var seq = 100;
        await db.enrollmentsDao.applyRollover(
          spaceId: 'sp1',
          newTermId: 't3',
          newTerm: TermsCompanion.insert(
            id: 't3',
            spaceId: 'sp1',
            name: '2027–28',
            startsOn: '2027-09-01',
            createdAt: now,
            updatedAt: now,
            isCurrent: const Value(1),
          ),
          returning: {'s1': 'g1'},
          newId: () => 'en${seq++}',
          nowIso: now,
        );
        final all = await db.select(db.enrollments).get();
        // Three from the first period (now closed) + one new open one.
        expect(all.where((e) => e.endedAt != null).length, 3);
        expect(all.where((e) => e.endedAt == null).length, 1);
        // Only one period is current.
        final current = await (db.select(
          db.terms,
        )..where((t) => t.isCurrent.equals(1))).get();
        expect(current.length, 1);
        expect(current.single.id, 't3');
      },
    );

    test('undo puts the room back exactly as it was', () async {
      await db
          .into(db.terms)
          .insert(
            TermsCompanion.insert(
              id: 't1',
              spaceId: 'sp1',
              name: '2025–26',
              startsOn: '2025-09-01',
              createdAt: now,
              updatedAt: now,
              isCurrent: const Value(1),
            ),
          );
      await db
          .into(db.enrollments)
          .insert(
            EnrollmentsCompanion.insert(
              id: 'old1',
              spaceId: 'sp1',
              subjectId: 's3',
              termId: 't1',
              startedAt: now,
              createdAt: now,
              updatedAt: now,
              groupId: const Value('g2'),
            ),
          );
      await roll({'s1': 'g1', 's2': 'g1'}); // s3 → alumni
      await db.enrollmentsDao.undoRollover(
        spaceId: 'sp1',
        termId: 't2',
        previousTermId: 't1',
        nowIso: now,
      );

      final liam = await (db.select(
        db.subjects,
      )..where((s) => s.id.equals('s3'))).getSingle();
      expect(liam.status, 'enrolled', reason: 'un-alumni-ed');
      final old = await (db.select(
        db.enrollments,
      )..where((e) => e.id.equals('old1'))).getSingle();
      expect(old.endedAt, isNull, reason: 're-opened');
      final t2 = await (db.select(
        db.terms,
      )..where((t) => t.id.equals('t2'))).getSingleOrNull();
      expect(t2, isNull, reason: 'the new period is gone');
      final current = await (db.select(
        db.terms,
      )..where((t) => t.isCurrent.equals(1))).getSingle();
      expect(current.id, 't1');
    });

    test('a newly created child gets an EXPLICIT status', () async {
      // Not cosmetic: status is nullable locally (PowerSync columns always
      // are) but NOT NULL on the server, and a Postgres default only
      // applies to an OMITTED column. An explicit null would fail the
      // insert forever and stall every later upload behind it.
      await db.subjectsDao.create(
        id: 'new1',
        spaceId: 'sp1',
        groupId: 'g1',
        firstName: 'New',
        lastName: 'Child',
      );
      final row = await (db.select(
        db.subjects,
      )..where((s) => s.id.equals('new1'))).getSingle();
      expect(row.status, 'enrolled');
    });

    test('a row with NULL status still counts as enrolled', () async {
      // The upgrade window: `status` is a new column, so between an app
      // update and the first sync that carries it every existing local row
      // has NULL there. If the roster queries tested `status = 'enrolled'`
      // alone, every child in the program would vanish from every roster —
      // the exact disappearance this feature exists to prevent.
      await db.customStatement('UPDATE subjects SET status = NULL');
      final inRoom = await db.subjectsDao.watchInGroup('g1').first;
      final inSpace = await db.subjectsDao.watchInSpace('sp1').first;
      expect(inRoom.length, 2, reason: 'NULL is not "gone"');
      expect(inSpace.length, 3);
      // …and they can still be rolled over.
      await roll({'s1': 'g1', 's2': 'g1', 's3': 'g2'});
      final rows = await db.select(db.enrollments).get();
      expect(rows.length, 3);
    });

    test('alumni actually leave the rosters', () async {
      await roll({'s1': 'g1', 's2': 'g1'}); // s3 → alumni
      final inRoom = await db.subjectsDao.watchInGroup('g2').first;
      final inSpace = await db.subjectsDao.watchInSpace('sp1').first;
      expect(inRoom, isEmpty, reason: 'g2 only held the alumnus');
      // Ordered by first name (Ava before Owen), which is what the roster
      // queries promise — assert the SET, not an incidental order.
      expect(inSpace.map((s) => s.id).toSet(), {'s1', 's2'});
      // But they are still reachable on purpose.
      final alumni = await db.subjectsDao.watchAlumniInSpace('sp1').first;
      expect(alumni.map((s) => s.id), ['s3']);
    });

    test(
      'undo works on the FIRST rollover, when there is no prior period',
      () async {
        await roll({'s1': 'g1', 's2': 'g1'});
        await db.enrollmentsDao.undoRollover(
          spaceId: 'sp1',
          termId: 't2',
          previousTermId: null,
          nowIso: now,
        );
        final kids = await db.select(db.subjects).get();
        expect(kids.every((s) => s.status == 'enrolled'), isTrue);
        expect(await db.select(db.enrollments).get(), isEmpty);
        expect(await db.select(db.terms).get(), isEmpty);
      },
    );

    test('an alumnus can be brought back', () async {
      await roll({'s1': 'g1', 's2': 'g1'});
      await db.enrollmentsDao.reinstate('s3', now);
      final liam = await (db.select(
        db.subjects,
      )..where((s) => s.id.equals('s3'))).getSingle();
      expect(liam.status, 'enrolled');
    });
  });
}
