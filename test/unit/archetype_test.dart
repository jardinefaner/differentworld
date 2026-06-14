// The archetype foundation (docs/IDENTITY_SYSTEM.md §2): the catalog is
// well-formed, and setArchetype round-trips through the member caps blob
// (decorates, never gates) — exercised end-to-end on the in-memory DB harness.

import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/role_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/identity/archetypes.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:differentworld/features/today/role_tools.dart';
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

  group('Role-3: archetype tunes the palette (decorates, never gates)', () {
    // Every role's pre-capability palette (toolsForRole) under test, incl. the
    // default branch (any unknown role key → the basics).
    const roles = [
      RoleKey.director,
      RoleKey.leadTeacher,
      RoleKey.teacher,
      RoleKey.specialist,
      RoleKey.substitute,
      'kitchen',
    ];

    test('every catalog archetype has a non-empty affinity entry', () {
      for (final a in kArchetypes) {
        expect(
          archetypeToolAffinity[a.id],
          isNotEmpty,
          reason: 'no affinity for ${a.id}',
        );
      }
      // …and no orphan affinity keys pointing at a deleted archetype.
      final catalogIds = kArchetypes.map((a) => a.id).toSet();
      for (final id in archetypeToolAffinity.keys) {
        expect(catalogIds, contains(id), reason: 'orphan affinity: $id');
      }
    });

    test('every affinity route is a real tool route', () {
      final allRoutes = {
        for (final r in roles)
          for (final t in toolsForRole(r)) t.route,
      };
      for (final entry in archetypeToolAffinity.entries) {
        for (final route in entry.value) {
          expect(
            allRoutes,
            contains(route),
            reason: '${entry.key} affinity route $route is not a tool route',
          );
        }
      }
    });

    test('tuning only re-orders — never adds/removes (the gate proof)', () {
      for (final role in roles) {
        final base = toolsForRole(role);
        for (final a in kArchetypes) {
          final tuned = tuneByAffinity(base, a.id);
          expect(
            tuned.length,
            base.length,
            reason: '${a.id} changed $role palette length',
          );
          expect(
            tuned.map((t) => t.route).toSet(),
            base.map((t) => t.route).toSet(),
            reason: '${a.id} changed $role palette membership',
          );
        }
      }
    });

    test('no / unknown archetype → identical order (Role-1 floor)', () {
      for (final role in roles) {
        final base = toolsForRole(role).map((t) => t.route).toList();
        expect(
          tuneByAffinity(toolsForRole(role), null).map((t) => t.route).toList(),
          base,
        );
        expect(
          tuneByAffinity(
            toolsForRole(role),
            'not-an-archetype',
          ).map((t) => t.route).toList(),
          base,
        );
      }
    });

    test('affinity tools float to the front in role-relative order', () {
      // Director: insights, program, team, schedule, present, capture.
      // Doer affinity {captures/new, checklist}: director has Capture (last),
      // not Checklist → Capture floats to front; the rest keep role order.
      final tuned = tuneByAffinity(toolsForRole(RoleKey.director), 'doer');
      expect(tuned.first.route, '/captures/new');
      expect(
        tuned.where((t) => t.route != '/captures/new').map((t) => t.route),
        ['/insights', '/settings/program', '/settings/team', '/schedule',
            '/present'],
      );
    });

    test('multi-affinity tools keep their relative order at the front', () {
      // Lead teacher: present, observe, liveBoard, schedule, breaks, capture.
      // Beacon affinity {present, live-board}: both present → lead in role order.
      final tuned = tuneByAffinity(toolsForRole(RoleKey.leadTeacher), 'beacon');
      expect(tuned.take(2).map((t) => t.route).toList(), [
        '/present',
        '/live-board',
      ]);
    });
  });
}
