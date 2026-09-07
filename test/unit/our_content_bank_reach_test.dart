// An authored row is only worth writing if the ACTIVITY can see it. These
// exercise the seam between the CRUD door (`content_items` with a space id and
// `source='staff'`) and the bank every activity reads — the place where a
// wrong key or a wrong scope makes a teacher's work silently invisible.

import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/game_content/content_kinds.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('authored rows reach the activity', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.createMigrator().createAll();
    });

    tearDown(() async => db.close());

    Future<void> author(String kind, Map<String, Object?> payload) {
      return db.contentBankDao.createStaffItem(
        spaceId: 'sp1',
        kind: kind,
        payload: jsonEncode(payload),
        createdBy: 'm1',
      );
    }

    test('a written pair lands in the bank the game draws from', () async {
      await author(ContentKind.thisOrThat, {'a': 'Playground', 'b': 'Gym'});
      final rows = await db.contentBankDao.watchForSpace('sp1').first;
      expect(rows, hasLength(1));

      // The merge the real provider performs, then the read a game performs.
      final bank = LocalContentBank([
        for (final r in rows)
          ContentItem(
            kind: r.kind,
            fingerprint: r.fingerprint,
            payload: jsonDecode(r.payload) as Map<String, Object?>,
          ),
      ]);
      final item = bank.next(ContentKind.thisOrThat);
      expect(item, isNotNull);
      expect(item!.payload['a'], 'Playground');
      expect(item.payload['b'], 'Gym');
    });

    test(
      'two identical items both survive — a room may repeat itself',
      () async {
        await author(ContentKind.question, {'text': 'What made you laugh?'});
        await author(ContentKind.question, {'text': 'What made you laugh?'});
        final rows = await db.contentBankDao
            .watchOwnByKind(
              'sp1',
              ContentKind.question,
            )
            .first;
        expect(
          rows,
          hasLength(2),
          reason:
              'staff items fingerprint on their own id, so authored rows never '
              'collapse against each other the way crowd rows do',
        );
      },
    );

    test("another program's rows never reach this one", () async {
      await db.contentBankDao.createStaffItem(
        spaceId: 'sp2',
        kind: ContentKind.riddle,
        payload: jsonEncode({'prompt': 'p', 'answer': 'a'}),
      );
      final rows = await db.contentBankDao.watchForSpace('sp1').first;
      expect(rows, isEmpty);
    });

    test('a crowd-grown row also shows in the library', () async {
      await db.contentBankDao.bankCrowdItem(
        spaceId: 'sp1',
        kind: ContentKind.riddle,
        fingerprint: 'fp1',
        payload: jsonEncode({'prompt': 'p', 'answer': 'a'}),
      );
      final own = await db.contentBankDao
          .watchOwnByKind(
            'sp1',
            ContentKind.riddle,
          )
          .first;
      expect(
        own,
        hasLength(1),
        reason: 'the library lists what this program produced',
      );
    });

    test(
      'delete then restore keeps the SAME id, so it re-syncs as itself',
      () async {
        final id = await db.contentBankDao.createStaffItem(
          spaceId: 'sp1',
          kind: ContentKind.question,
          payload: jsonEncode({'text': 'What did you build?'}),
        );
        await db.contentBankDao.deleteById(id);
        expect(
          await db.contentBankDao
              .watchOwnByKind('sp1', ContentKind.question)
              .first,
          isEmpty,
        );

        await db.contentBankDao.createStaffItem(
          id: id,
          spaceId: 'sp1',
          kind: ContentKind.question,
          payload: jsonEncode({'text': 'What did you build?'}),
        );
        final rows = await db.contentBankDao
            .watchOwnByKind('sp1', ContentKind.question)
            .first;
        expect(rows, hasLength(1));
        expect(rows.first.id, id);
      },
    );

    test('every authorable kind round-trips through the bank', () async {
      for (final spec in authorableKinds) {
        await author(spec.kind, {
          for (final f in spec.fields)
            f.key: switch (f.shape) {
              ContentFieldShape.flag => true,
              ContentFieldShape.list => const ['one', 'two'],
              _ => 'sample ${f.key}',
            },
        });
      }
      final rows = await db.contentBankDao.watchForSpace('sp1').first;
      expect(rows, hasLength(authorableKinds.length));
      for (final spec in authorableKinds) {
        final row = rows.firstWhere((r) => r.kind == spec.kind);
        final payload = jsonDecode(row.payload) as Map<String, Object?>;
        expect(
          payload.keys.toSet(),
          spec.fields.map((f) => f.key).toSet(),
          reason: '${spec.kind} lost a key on the way to the bank',
        );
        expect(spec.summarize(payload), isNotEmpty);
      }
    });
  });
}
