// The archetype foundation (docs/IDENTITY_SYSTEM.md §2): the catalog is
// well-formed, and setArchetype round-trips through the member caps blob
// (decorates, never gates) — exercised end-to-end on the in-memory DB harness.

import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/identity/archetypes.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalog', () {
    test('8 archetypes, unique ids, all fields present', () {
      expect(kArchetypes, hasLength(8));
      final ids = kArchetypes.map((a) => a.id).toSet();
      expect(ids, hasLength(8), reason: 'ids must be unique');
      for (final a in kArchetypes) {
        expect(a.id, isNotEmpty);
        expect(a.glyph, isNotEmpty);
        expect(a.name, isNotEmpty);
        expect(a.essence, isNotEmpty);
        expect(a.gift, isNotEmpty);
      }
    });

    test('archetypeById resolves known + degrades on unknown/null', () {
      expect(archetypeById('sage')?.name, 'Sage');
      expect(archetypeById('beacon')?.name, 'Beacon');
      expect(archetypeById('nope'), isNull);
      expect(archetypeById(null), isNull);
      expect(archetypeById(''), isNull);
    });
  });

  group('setArchetype round-trips through member caps', () {
    late AppDatabase db;
    late ProviderContainer container;
    const now = '2026-06-13T00:00:00Z';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.createMigrator().createAll();
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
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWith((ref) => db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<Viewer> viewerFor(String id) async {
      final m = await (db.select(db.members)..where((t) => t.id.equals(id)))
          .getSingle();
      return Viewer(member: m, space: null);
    }

    test('set then read via the viewer; clear resets it', () async {
      final actions = container.read(memberCapActionsProvider);

      await actions.setArchetype('m1', 'sage');
      var v = await viewerFor('m1');
      expect(v.archetypeId, 'sage');
      expect(archetypeById(v.archetypeId)?.name, 'Sage');

      await actions.setArchetype('m1', null);
      v = await viewerFor('m1');
      expect(v.archetypeId, isNull);
    });

    test('archetype never affects a capability gate (decorates only)', () async {
      final actions = container.read(memberCapActionsProvider);
      await actions.setArchetype('m1', 'protector');
      final v = await viewerFor('m1');
      // Setting an archetype must not grant any boolean cap.
      expect(v.canObserve, isFalse);
      expect(v.canManageSpace, isFalse);
      expect(v.memberCaps.getString(MemberCaps.archetype), 'protector');
    });
  });
}
