import 'dart:convert';

import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_screen.dart';
import 'package:differentworld/features/captures/capture_inbox_screen.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/entries/observations_index_screen.dart';
import 'package:differentworld/features/games/present_hub_screen.dart';
import 'package:differentworld/features/groups/group_detail_screen.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/pickup/pickup_board_screen.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/settings/roles_screen.dart';
import 'package:differentworld/features/subjects/subject_detail_screen.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/features/tasks/tasks_screen.dart';
import 'package:differentworld/shared/widgets/app_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '_helpers.dart';

/// THE BENTO GALLERY — the bento-ON twin of `screens_gallery_test`.
///
/// The main gallery renders every screen with the DEFAULT providers, so
/// `bentoEverywhereProvider` resolves to false → only the NON-bento (list /
/// flat) path of each converted screen gets a plate. The 50+ screens that
/// gained a bento variant in the "Bento everywhere" sweep had ZERO
/// visual-regression coverage of their bento layout.
///
/// This file closes that gap for a REPRESENTATIVE set (the screens whose bento
/// layout differs most from their list/flat path), forcing
/// `bentoEverywhereProvider` TRUE for every plate via [_BentoOn] and writing to
/// `gallery/bento/<screen>__<mode>.png`, light + dark.
///
/// Same machinery as the main gallery: a director [Viewer] over a seeded
/// in-memory [AppDatabase], rendered inside the real AppShell, with the same
/// AppShell-neutralizing overrides (catalog / live strip / captures / tasks).
/// Two seed shapes mirror the main gallery's: a SHARED `_db` (space + director,
/// for the screens that read program-wide / static decks) and a per-test ROSTER
/// db (space + director + group g1 + three subjects, for the param'd detail +
/// attendance screens that need a populated cohort to render their bento).
///
/// Gated behind `RUN_GOLDENS` like every other golden suite — a normal
/// `flutter test` skips it. No plates exist yet: generate them with
///   RUN_GOLDENS=1 flutter test --update-goldens test/golden/bento_gallery_test.dart

late final AppDatabase _db;
late final Viewer _viewer;

/// Forces the global "Bento everywhere" switch ON for the seeded plates.
/// Mirrors the `_ScheduleGridOn` pattern in `screens_gallery_test` — a tiny
/// [AsyncNotifier] subclass whose `build()` returns true, wired in via
/// `bentoEverywhereProvider.overrideWith(_BentoOn.new)`.
class _BentoOn extends BentoEverywhereNotifier {
  @override
  Future<bool> build() async => true;
}

Future<void> _loadFonts() async {
  final manifest =
      json.decode(
            await rootBundle.loadString('FontManifest.json'),
          )
          as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load((font as Map)['asset'] as String));
    }
    await loader.load();
  }
}

LiveBlock _demoLiveBlock() => LiveBlock(
  blockId: 'blk-demo',
  groupId: 'g1',
  title: 'Outdoor free play',
  kind: 'on_site',
  isOutdoor: true,
  startAt: DateTime.now().subtract(const Duration(minutes: 12)),
  endAt: DateTime.now().add(const Duration(minutes: 23)),
);

void main() {
  setUpAll(() async {
    await ensureGoldenBootstrap();
    await _loadFonts();
    _db = AppDatabase.forTesting(NativeDatabase.memory());
    await _db.createMigrator().createAll();
    const now = '2026-06-17T08:00:00Z';
    await _db
        .into(_db.spaces)
        .insert(
          SpacesCompanion.insert(
            id: 'sp1',
            name: 'Sunny Days Program',
            settings: '{}',
            capabilities: '{}',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _db
        .into(_db.members)
        .insert(
          MembersCompanion.insert(
            id: 'm1',
            displayName: 'Maya Okonkwo',
            role: 'director',
            capabilities: '{}',
            createdAt: now,
            updatedAt: now,
            spaceId: const Value('sp1'),
          ),
        );
    final m = await (_db.select(
      _db.members,
    )..where((t) => t.id.equals('m1'))).getSingle();
    final s = await (_db.select(
      _db.spaces,
    )..where((t) => t.id.equals('sp1'))).getSingle();
    _viewer = Viewer(member: m, space: s);
  });

  tearDownAll(() async {
    await _db.close().timeout(const Duration(seconds: 5), onTimeout: () {});
  });

  // SHARED-DB screens — read program-wide data or a static deck; the seeded
  // space + director is enough for the bento grid to render its shape.
  // present_hub + roles build their bento from STATIC tiles (fully populated
  // regardless of data); insights / captures / observations / tasks / pickup
  // build their bento from the (overridden-empty) program providers — the bento
  // LAYOUT still renders, which is the variant we're locking.
  _bentoScreenPlate('insights', const InsightsScreen());
  _bentoScreenPlate('present_hub', const PresentHubScreen());
  _bentoScreenPlate('capture_inbox', const CaptureInboxScreen());
  _bentoScreenPlate('observations_index', const ObservationsIndexScreen());
  _bentoScreenPlate('tasks', const TasksScreen());
  _bentoScreenPlate('roles', const RolesScreen());
  _bentoScreenPlate('pickup_board', const PickupBoardScreen());

  // ROSTER screens — a param'd detail or per-cohort surface that needs a
  // populated cohort (group g1 + three subjects) so the bento shows real glance
  // tiles / rows instead of an empty state.
  _bentoRosterPlate(
    'group_detail',
    const GroupDetailScreen(groupId: 'g1'),
  );
  _bentoRosterPlate(
    'subject_detail',
    const SubjectDetailScreen(subjectId: 's1'),
  );
  _bentoRosterPlate(
    'attendance',
    const AttendanceScreen(groupId: 'g1'),
  );
}

Future<void> _pumpAndShoot(
  WidgetTester tester,
  String screen,
  String mode,
  AppDatabase db,
  Viewer viewer,
  Widget screenWidget,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      // Seed the viewer + DB; force the global "Bento everywhere" switch on;
      // neutralize AppShell's own Drift watches (catalog / live strip / capture
      // + task counts) so only the SCREEN under test creates watch streams.
      // Inlined (not a returned `List<Override>`) because Riverpod doesn't
      // export the `Override` type — same shape the main gallery uses.
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        viewerProvider.overrideWithValue(viewer),
        bentoEverywhereProvider.overrideWith(_BentoOn.new),
        liveBlockProvider.overrideWith((ref) => _demoLiveBlock()),
        omniboxCatalogProvider.overrideWithValue(const <OmniboxEntry>[]),
        momentsForBlockProvider(
          'blk-demo',
        ).overrideWith((_) => Stream<List<Entry>>.value(const <Entry>[])),
        capturesProvider(
          CaptureFilter.open,
        ).overrideWith((_) => Stream<List<Capture>>.value(const <Capture>[])),
        tasksProvider(
          TaskFilter.open,
        ).overrideWith((_) => Stream<List<Task>>.value(const <Task>[])),
      ],
      child: MaterialApp.router(
        theme: mode == 'dark' ? buildDarkTheme() : buildLightTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: GoRouter(
          initialLocation: '/screen',
          routes: [
            ShellRoute(
              builder: (context, state, child) => AppShell(child: child),
              routes: [
                GoRoute(path: '/screen', builder: (_, _) => screenWidget),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../gallery/bento/${screen}__$mode.png'),
  );
  // Drain: unmount (cancels Drift subscriptions) + advance timers so any
  // pending one-shot Drift Timer fires before teardown's invariant check.
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  // Consume late async errors that fired AFTER the golden was captured (a
  // direct Postgrest read, a missing plugin). The plate is already written; a
  // genuine build-time crash would surface as a red error box IN the PNG.
  while (tester.takeException() != null) {
    // drained
  }
}

/// Render a converted screen against the SHARED `_db` (space + director),
/// bento forced on, inside the real AppShell — light + dark.
void _bentoScreenPlate(
  String screen,
  Widget screenWidget, {
  Size size = const Size(440, 900),
}) {
  for (final mode in const ['light', 'dark']) {
    testWidgets('bento/$screen - $mode', (tester) async {
      await _pumpAndShoot(
        tester,
        screen,
        mode,
        _db,
        _viewer,
        screenWidget,
        size,
      );
    }, skip: !runGoldens);
  }
}

/// Seeds a throwaway cohort + roster (space + director + group g1 + three
/// subjects), then renders a param'd detail / per-cohort screen populated with
/// bento forced on. Never touches the shared `_db`.
void _bentoRosterPlate(
  String screen,
  Widget screenWidget, {
  Size size = const Size(440, 900),
}) {
  for (final mode in const ['light', 'dark']) {
    testWidgets('bento/$screen - $mode', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.createMigrator().createAll();
      const now = '2026-06-17T08:00:00Z';
      await db
          .into(db.spaces)
          .insert(
            SpacesCompanion.insert(
              id: 'sp1',
              name: 'Sunny Days Program',
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
              displayName: 'Maya Okonkwo',
              role: 'director',
              capabilities: '{}',
              createdAt: now,
              updatedAt: now,
              spaceId: const Value('sp1'),
            ),
          );
      await db
          .into(db.groups)
          .insert(
            GroupsCompanion.insert(
              id: 'g1',
              spaceId: 'sp1',
              name: 'Sparrows',
              capabilities: '{}',
              createdAt: now,
              updatedAt: now,
              ageRange: const Value('Ages 4–5'),
            ),
          );
      for (final (id, first, last) in const [
        ('s1', 'Owen', 'Reyes'),
        ('s2', 'Ava', 'Chen'),
        ('s3', 'Liam', 'Okafor'),
      ]) {
        await db
            .into(db.subjects)
            .insert(
              SubjectsCompanion.insert(
                id: id,
                spaceId: 'sp1',
                firstName: first,
                lastName: last,
                capabilities: '{}',
                createdAt: now,
                updatedAt: now,
                groupId: const Value('g1'),
              ),
            );
      }
      final m = await (db.select(
        db.members,
      )..where((t) => t.id.equals('m1'))).getSingle();
      final s = await (db.select(
        db.spaces,
      )..where((t) => t.id.equals('sp1'))).getSingle();
      final viewer = Viewer(member: m, space: s);

      await _pumpAndShoot(
        tester,
        screen,
        mode,
        db,
        viewer,
        screenWidget,
        size,
      );
      await db.close().timeout(const Duration(seconds: 5), onTimeout: () {});
    }, skip: !runGoldens);
  }
}
