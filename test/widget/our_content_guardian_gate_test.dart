// Authoring is staff-only, and it is guarded at the SCREEN, not only at the
// entry points — /library/ours is a deep link, and hiding a button is not
// gating an action (CLAUDE.md).
//
// This matters more than it looks: a GuardianViewer DOES carry a spaceId
// (`guardian.spaceId`), so `OurContentActions.create` would have SUCCEEDED for
// a guardian and written a staff-authored row into the program's content bank.
// The data layer was never the gate.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/game_content/our_content_form_screen.dart';
import 'package:differentworld/features/game_content/our_content_kind_screen.dart';
import 'package:differentworld/features/game_content/our_content_library_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Space space;
  late Guardian guardian;
  late Member member;
  const now = '2026-09-07T00:00:00Z';

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
    await db
        .into(db.guardians)
        .insert(
          GuardiansCompanion.insert(
            id: 'gd1',
            spaceId: 'sp1',
            name: 'Lauren',
            createdAt: now,
            updatedAt: now,
          ),
        );
    space = await (db.select(
      db.spaces,
    )..where((t) => t.id.equals('sp1'))).getSingle();
    member = await (db.select(
      db.members,
    )..where((t) => t.id.equals('m1'))).getSingle();
    guardian = await (db.select(
      db.guardians,
    )..where((t) => t.id.equals('gd1'))).getSingle();
  });

  tearDown(() async => db.close());

  Widget as(Viewer viewer, Widget child) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      viewerProvider.overrideWithValue(viewer),
    ],
    child: MaterialApp(home: child),
  );

  Viewer familyViewer() => GuardianViewer(
    guardian: guardian,
    childSubjectIds: const ['s1'],
    space: space,
  );

  Viewer staffViewer() => Viewer(member: member, space: space);

  test('a guardian carries a spaceId — the DAO was never the gate', () {
    expect(familyViewer().spaceId, 'sp1');
  });

  testWidgets('the library index refuses a guardian', (tester) async {
    await tester.pumpWidget(
      as(familyViewer(), const OurContentLibraryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('This is for the team'), findsOneWidget);
    expect(find.text('Our own'), findsNothing);
  });

  testWidgets('a deep link straight to a kind refuses a guardian', (
    tester,
  ) async {
    await tester.pumpWidget(
      as(familyViewer(), const OurContentKindScreen(kind: ContentKind.riddle)),
    );
    await tester.pumpAndSettle();

    expect(find.text('This is for the team'), findsOneWidget);
    expect(find.text('Add a riddle'), findsNothing);
  });

  testWidgets('a deep link straight to the form refuses a guardian', (
    tester,
  ) async {
    await tester.pumpWidget(
      as(familyViewer(), const OurContentFormScreen(kind: ContentKind.riddle)),
    );
    await tester.pumpAndSettle();

    expect(find.text('This is for the team'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Keep it'), findsNothing);
  });

  testWidgets('staff still get in — the gate is a gate, not a wall', (
    tester,
  ) async {
    await tester.pumpWidget(as(staffViewer(), const OurContentLibraryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('This is for the team'), findsNothing);
    expect(find.text('Our own'), findsOneWidget);
    expect(find.text('This or that'), findsOneWidget);
  });
}
