// Staff-authored game content rides the existing `content_items` table (no new
// table). These exercise the DAO surface the picture library + the offline
// upload-queue swap depend on, on the in-memory Drift harness.

import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentBankDao — staff picture CRUD + offline swap', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.createMigrator().createAll();
    });

    tearDown(() async => db.close());

    test('createStaffItem + watchOwnByKind round-trips a picture', () async {
      final id = await db.contentBankDao.createStaffItem(
        id: 'pic1',
        spaceId: 'sp1',
        kind: 'picture',
        payload: jsonEncode({'image': 'pending:pic1', 'label': 'Our dog'}),
      );
      expect(id, 'pic1', reason: 'honors the caller-supplied id');
      final rows =
          await db.contentBankDao.watchOwnByKind('sp1', 'picture').first;
      expect(rows, hasLength(1));
      final p = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(p['label'], 'Our dog');
      expect(p['image'], 'pending:pic1');
    });

    test('updatePicturePath swaps the image, preserves the label', () async {
      await db.contentBankDao.createStaffItem(
        id: 'pic1',
        spaceId: 'sp1',
        kind: 'picture',
        payload: jsonEncode({'image': 'pending:pic1', 'label': 'Our dog'}),
      );
      await db.contentBankDao
          .updatePicturePath('pic1', 'sp1/custom_picture/pic1/x.jpg');
      final rows =
          await db.contentBankDao.watchOwnByKind('sp1', 'picture').first;
      final p = jsonDecode(rows.first.payload) as Map<String, dynamic>;
      expect(p['image'], 'sp1/custom_picture/pic1/x.jpg',
          reason: 'the offline queue swaps pending → real path');
      expect(p['label'], 'Our dog', reason: 'label survives the swap');
    });

    test('updatePicturePath is a no-op when the row is gone', () async {
      // Deleted before the offline upload landed — must not throw.
      await db.contentBankDao.updatePicturePath('ghost', 'whatever');
      final rows =
          await db.contentBankDao.watchOwnByKind('sp1', 'picture').first;
      expect(rows, isEmpty);
    });

    test('watchOwnByKind is scoped to space + kind (excludes global/other)',
        () async {
      await db.contentBankDao.createStaffItem(
          id: 'a', spaceId: 'sp1', kind: 'picture', payload: '{}');
      await db.contentBankDao.createStaffItem(
          id: 'b', spaceId: 'sp1', kind: 'riddle', payload: '{}');
      // Another space's picture must not leak into sp1's library.
      await db.contentBankDao.bankCrowdItem(
          spaceId: 'sp2', kind: 'picture', fingerprint: 'f', payload: '{}');
      final rows =
          await db.contentBankDao.watchOwnByKind('sp1', 'picture').first;
      expect(rows.map((r) => r.id), ['a']);
    });

    test('deleteById removes an authored item', () async {
      await db.contentBankDao.createStaffItem(
          id: 'pic1', spaceId: 'sp1', kind: 'picture', payload: '{}');
      await db.contentBankDao.deleteById('pic1');
      final rows =
          await db.contentBankDao.watchOwnByKind('sp1', 'picture').first;
      expect(rows, isEmpty);
    });
  });
}
