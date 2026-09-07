// The authoring door, end to end on a real in-memory Drift DB: type into the
// generated form, save, and see the row in the list the activity reads from
// (docs/CONDITIONS.md). Uses the action-layer harness so nothing about the
// write is mocked — a wrong payload key would show up here.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/game_content/our_content.dart';
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
  late Member member;
  late Space space;
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
    member = await (db.select(
      db.members,
    )..where((t) => t.id.equals('m1'))).getSingle();
    space = await (db.select(
      db.spaces,
    )..where((t) => t.id.equals('sp1'))).getSingle();
  });

  tearDown(() async => db.close());

  /// Read the space's own rows from inside a widget test. A Drift stream
  /// awaited in `testWidgets`' fake-async zone never completes — the read has
  /// to happen in real async, via `runAsync`.
  Future<List<ContentItemRow>> ours(WidgetTester tester, String kind) async {
    // Filtered in Dart, not SQL: `show Value` keeps drift's `Column` out of
    // this file (it collides with Material's), which also hides the `&`
    // operator on expressions.
    final rows = await tester.runAsync(() => db.select(db.contentItems).get());
    return (rows ?? const <ContentItemRow>[])
        .where((r) => r.spaceId == 'sp1' && r.kind == kind)
        .toList();
  }

  /// Tap "Keep it" and let the real DB write land. The save crosses a real
  /// async boundary, which `pumpAndSettle` alone cannot drive.
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Keep it'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      viewerProvider.overrideWithValue(Viewer(member: member, space: space)),
    ],
    child: MaterialApp(home: child),
  );

  Widget form(String kind) => wrap(OurContentFormScreen(kind: kind));

  Widget listing(String kind, List<OurContentItem> items) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => db),
      viewerProvider.overrideWithValue(Viewer(member: member, space: space)),
      ourContentProvider(kind).overrideWith((ref) => Stream.value(items)),
    ],
    child: MaterialApp(home: OurContentKindScreen(kind: kind)),
  );

  testWidgets('the form is generated from the kind — two labelled fields', (
    tester,
  ) async {
    await tester.pumpWidget(form(ContentKind.thisOrThat));
    await tester.pumpAndSettle();

    expect(find.text('Add a pair'), findsOneWidget);
    expect(find.text('One thing'), findsOneWidget);
    expect(find.text('Or the other'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Keep it'), findsOneWidget);
  });

  testWidgets('an empty required field blocks the save and says so', (
    tester,
  ) async {
    await tester.pumpWidget(form(ContentKind.thisOrThat));
    await tester.pumpAndSettle();

    await save(tester);

    expect(find.text('Add one thing'), findsOneWidget);
    final rows = await ours(tester, ContentKind.thisOrThat);
    expect(rows, isEmpty, reason: 'nothing was written');
  });

  testWidgets('typing both halves and saving writes a row the bank can read', (
    tester,
  ) async {
    await tester.pumpWidget(form(ContentKind.thisOrThat));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Playground');
    await tester.enterText(fields.at(1), 'Gym');
    await save(tester);

    final rows = await ours(tester, ContentKind.thisOrThat);
    expect(rows, hasLength(1));
    final payload = decodeContentPayload(rows.first.payload)!;
    expect(payload['a'], 'Playground');
    expect(payload['b'], 'Gym');
    expect(rows.first.createdBy, 'm1', reason: 'the author is recorded');
  });

  testWidgets('a list field stores lines as a list, not one string', (
    tester,
  ) async {
    await tester.pumpWidget(form(ContentKind.fillBlank));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Our pet is a {0} who likes to {1}.');
    await tester.enterText(fields.at(1), 'an animal\nan action word');
    await save(tester);

    final rows = await ours(tester, ContentKind.fillBlank);
    final payload = decodeContentPayload(rows.first.payload)!;
    expect(payload['blanks'], ['an animal', 'an action word']);
  });

  testWidgets('an unknown kind explains itself instead of rendering a blank', (
    tester,
  ) async {
    await tester.pumpWidget(form('not_a_kind'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("isn't something you can write"),
      findsOneWidget,
    );
  });

  testWidgets('the list shows what was written, and offers to add more', (
    tester,
  ) async {
    await tester.pumpWidget(
      listing(ContentKind.riddle, [
        const OurContentItem(
          id: 'r1',
          kind: ContentKind.riddle,
          payload: {'prompt': 'What has hands?', 'answer': 'A clock'},
          createdAt: now,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Our riddles'), findsOneWidget);
    expect(find.text('What has hands?'), findsOneWidget);
    expect(find.text('A clock'), findsOneWidget);
    expect(find.text('Add a riddle'), findsOneWidget);
  });

  testWidgets('day one is one way in, not fifteen empty rows', (tester) async {
    await tester.pumpWidget(wrap(const OurContentLibraryScreen()));
    await tester.pumpAndSettle();

    // The first version listed every kind with "None yet" beside it — the
    // wall of rows this screen exists to avoid.
    expect(find.text('None yet'), findsNothing);
    expect(find.text('This or that'), findsNothing);
    expect(find.text('Nothing of yours yet'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Write something'),
      findsOneWidget,
    );
  });

  testWidgets('once something is written, the index leads with it', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWith((ref) => db),
          viewerProvider.overrideWithValue(
            Viewer(member: member, space: space),
          ),
          ourContentProvider(ContentKind.riddle).overrideWith(
            (ref) => Stream.value([
              const OurContentItem(
                id: 'r1',
                kind: ContentKind.riddle,
                payload: {'prompt': 'p', 'answer': 'a'},
                createdAt: now,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: OurContentLibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riddles'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    // Everything else stays behind one row.
    expect(find.text('Questions of the day'), findsNothing);
    expect(find.text('Write something else'), findsOneWidget);
  });

  testWidgets('the picker groups the full set by what it is for', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const OurContentPickerScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ask the room'), findsOneWidget);
    expect(find.text('This or that'), findsOneWidget);
    // Further down the list — a lazy ListView hasn't built it yet, which is
    // the point: the full set is here, but it is not what you land on.
    await tester.scrollUntilVisible(find.text('Riddles'), 200);
    expect(find.text('Riddles'), findsOneWidget);
    expect(find.text('Play with words'), findsOneWidget);
  });

  testWidgets('an empty list invites rather than showing a blank screen', (
    tester,
  ) async {
    await tester.pumpWidget(listing(ContentKind.question, const []));
    await tester.pumpAndSettle();

    expect(find.text('None of these are yours yet'), findsOneWidget);
    expect(find.text('Add a question'), findsWidgets);
  });
}
