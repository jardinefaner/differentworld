// The first-run starter spine (docs/BRAND.md "undeniable" onboarding):
// pins the pure SpineState machine (which cards show, when the section
// retires) and the Sam seeder/remover contracts — the sample child must
// arrive with a full story, be marked as sample, be pointed at by the
// space caps, and disappear wholesale on removal.

import 'dart:convert';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/onboarding/sample_child.dart';
import 'package:differentworld/features/onboarding/widgets/starter_spine.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Capabilities _caps(Map<String, Object?> m) =>
    Capabilities.fromJson(jsonEncode(m));

void main() {
  group('SpineState', () {
    test('fresh space: all three cards pending, section visible', () {
      final s = SpineState.of(
        _caps({
          SpaceCaps.onboardingStarted: true,
          SpaceCaps.onboardingSampleSubjectId: 'sam-1',
        }),
        groupCount: 0,
      );
      expect(s.castDone, isFalse);
      expect(s.sampleSeen, isFalse);
      expect(s.roomDone, isFalse);
      expect(s.doneCount, 0);
      expect(s.visible, isTrue);
      expect(s.showInvitesCloser, isFalse);
    });

    test('removed sample counts as seen — the card just goes', () {
      final s = SpineState.of(
        _caps({SpaceCaps.onboardingStarted: true}),
        groupCount: 0,
      );
      expect(s.sampleSeen, isTrue);
      expect(s.sampleSubjectId, isNull);
    });

    test('room added derives from data and reveals the invites closer', () {
      final s = SpineState.of(
        _caps({
          SpaceCaps.onboardingStarted: true,
          SpaceCaps.onboardingSampleSubjectId: 'sam-1',
        }),
        groupCount: 2,
      );
      expect(s.roomDone, isTrue);
      expect(s.showInvitesCloser, isTrue);
      expect(s.visible, isTrue);
    });

    test('retires only when all three + the closer are done', () {
      final almost = SpineState.of(
        _caps({
          SpaceCaps.onboardingStarted: true,
          SpaceCaps.onboardingCastDone: true,
          SpaceCaps.onboardingSampleSeen: true,
          SpaceCaps.onboardingSampleSubjectId: 'sam-1',
        }),
        groupCount: 1,
      );
      expect(almost.allDone, isFalse); // closer still pending
      final done = SpineState.of(
        _caps({
          SpaceCaps.onboardingStarted: true,
          SpaceCaps.onboardingCastDone: true,
          SpaceCaps.onboardingSampleSeen: true,
          SpaceCaps.onboardingSampleSubjectId: 'sam-1',
          SpaceCaps.onboardingInvitesDone: true,
        }),
        groupCount: 1,
      );
      expect(done.allDone, isTrue);
      expect(done.visible, isFalse);
    });

    test('a pre-existing program never sees a retroactive Day one', () {
      final s = SpineState.of(_caps({}), groupCount: 3);
      expect(s.started, isFalse);
      expect(s.visible, isFalse);
    });

    test('hide setup wins regardless of progress', () {
      final s = SpineState.of(
        _caps({
          SpaceCaps.onboardingStarted: true,
          SpaceCaps.onboardingDismissed: true,
          SpaceCaps.onboardingSampleSubjectId: 'sam-1',
        }),
        groupCount: 0,
      );
      expect(s.visible, isFalse);
    });
  });

  group('sample child seeding', () {
    late AppDatabase db;
    const spaceId = 'space-1';
    const memberId = 'member-1';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // Production's schema comes from PowerSync; in-memory tests
      // materialize it themselves (the action-layer harness pattern).
      await db.createMigrator().createAll();
      final now = DateTime.now().toUtc().toIso8601String();
      await db
          .into(db.spaces)
          .insert(
            SpacesCompanion.insert(
              id: spaceId,
              name: 'Test Program',
              settings: '{}',
              capabilities: '{}',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('seeds Sam with a full story, marked and pointed at', () async {
      final samId = await seedSampleChild(
        db,
        spaceId: spaceId,
        memberId: memberId,
      );

      final sam = await (db.select(
        db.subjects,
      )..where((s) => s.id.equals(samId))).getSingle();
      expect(sam.firstName, 'Sam');
      expect(sam.caps.getBool(SubjectCaps.isSample), isTrue);

      final entries = await (db.select(
        db.entries,
      )..where((e) => e.subjectId.equals(samId))).get();
      expect(entries.length, greaterThanOrEqualTo(12));
      expect(entries.every((e) => e.spaceId == spaceId), isTrue);
      expect(entries.any((e) => e.kind == 'mission'), isTrue);

      final space = await db.spacesDao.findById(spaceId);
      expect(
        space!.caps.getString(SpaceCaps.onboardingSampleSubjectId),
        samId,
      );
    });

    test(
      'removal cascades and clears the pointer, sparing real kids',
      () async {
        final samId = await seedSampleChild(
          db,
          spaceId: spaceId,
          memberId: memberId,
        );
        // A real child with a real entry must survive Sam's removal.
        final now = DateTime.now().toUtc().toIso8601String();
        await db
            .into(db.subjects)
            .insert(
              SubjectsCompanion.insert(
                id: 'real-kid',
                spaceId: spaceId,
                firstName: 'Ada',
                lastName: 'L',
                capabilities: '{}',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.entries)
            .insert(
              EntriesCompanion.insert(
                id: 'real-entry',
                spaceId: spaceId,
                subjectId: const Value('real-kid'),
                kind: 'observation',
                body: const Value('Real moment.'),
                details: '{}',
                recordedBy: memberId,
                recordedAt: now,
                updatedAt: now,
              ),
            );

        await removeSampleChild(db, spaceId: spaceId, subjectId: samId);

        final samRows = await (db.select(
          db.subjects,
        )..where((s) => s.id.equals(samId))).get();
        expect(samRows, isEmpty);
        final samEntries = await (db.select(
          db.entries,
        )..where((e) => e.subjectId.equals(samId))).get();
        expect(samEntries, isEmpty);

        final space = await db.spacesDao.findById(spaceId);
        expect(
          space!.caps.getString(SpaceCaps.onboardingSampleSubjectId),
          isNull,
        );
        final realEntries = await (db.select(
          db.entries,
        )..where((e) => e.subjectId.equals('real-kid'))).get();
        expect(realEntries.length, 1);
      },
    );
  });
}
