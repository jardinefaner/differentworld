// Role-4 (the kid verb-job reshapes kid-mode): the kid's only write path on
// KidJobScreen is ActionWordsActions.toggleDone. This pins it — and setPicks —
// end-to-end on the in-memory DB harness (docs/EXTENDING.md "Action-layer test
// harness"). Production opens AppDatabase over PowerSync; tests open it over
// NativeDatabase.memory() and materialize the schema with createAll().

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
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

  Future<ActionWordsDay> readDay(String subjectId) async {
    final entries = await db.entriesDao
        .watchForSubject(subjectId: subjectId, kind: EntryKind.actionWords)
        .first;
    return ActionWordsDay.fromEntry(entries.isEmpty ? null : entries.first);
  }

  test('setPicks writes the 3 verb picks (no jobs done yet)', () async {
    final actions = container.read(actionWordsActionsProvider);
    await actions.setPicks(
      subjectId: 's1',
      groupId: 'g1',
      date: todayKey(),
      verbIds: const ['carry', 'listen', 'build'],
    );
    final day = await readDay('s1');
    expect(day.verbPicks, ['carry', 'listen', 'build']);
    expect(day.hasPicks, isTrue);
    expect(day.done, isEmpty);
  });

  test(
    'toggleDone marks a job done, then undone, preserving the picks',
    () async {
      final actions = container.read(actionWordsActionsProvider);
      await actions.setPicks(
        subjectId: 's1',
        groupId: 'g1',
        date: todayKey(),
        verbIds: const ['carry', 'listen', 'build'],
      );

      // Kid taps "I did it!" on Listen.
      await actions.toggleDone(
        subjectId: 's1',
        date: todayKey(),
        verbId: 'listen',
      );
      var day = await readDay('s1');
      expect(day.done, contains('listen'));
      expect(day.doneCount, 1);
      expect(
        day.verbPicks,
        ['carry', 'listen', 'build'],
        reason: 'toggling done must not disturb the picks',
      );

      // Taps again to undo.
      await actions.toggleDone(
        subjectId: 's1',
        date: todayKey(),
        verbId: 'listen',
      );
      day = await readDay('s1');
      expect(day.done, isNot(contains('listen')));
      expect(day.isComplete, isFalse);
    },
  );

  test('all three jobs done → the day is complete', () async {
    final actions = container.read(actionWordsActionsProvider);
    const picks = ['carry', 'listen', 'build'];
    await actions.setPicks(
      subjectId: 's1',
      groupId: 'g1',
      date: todayKey(),
      verbIds: picks,
    );
    for (final v in picks) {
      await actions.toggleDone(subjectId: 's1', date: todayKey(), verbId: v);
    }
    final day = await readDay('s1');
    expect(day.isComplete, isTrue);
    expect(day.doneCount, 3);
  });
}
