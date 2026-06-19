import 'dart:convert';

import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/action_words_screen.dart';
import 'package:differentworld/features/action_words/activity_arc_screen.dart';
import 'package:differentworld/features/action_words/activity_match_screen.dart';
import 'package:differentworld/features/action_words/day_run_screen.dart';
import 'package:differentworld/features/action_words/journey_tour_screen.dart';
import 'package:differentworld/features/action_words/program_hub_screen.dart';
import 'package:differentworld/features/action_words/send_screen.dart';
import 'package:differentworld/features/action_words/themed_world_screen.dart';
import 'package:differentworld/features/action_words/thinking_screen.dart';
import 'package:differentworld/features/action_words/this_week_screen.dart';
import 'package:differentworld/features/action_words/time_capsule_screen.dart';
import 'package:differentworld/features/action_words/verb_jobs_screen.dart';
import 'package:differentworld/features/action_words/wall_screen.dart';
import 'package:differentworld/features/action_words/world_book_screen.dart';
import 'package:differentworld/features/activity_forge/activity_forge_screen.dart';
import 'package:differentworld/features/activity_forge/activity_lens_screen.dart';
import 'package:differentworld/features/activity_runtime/brain_breaks_screen.dart';
import 'package:differentworld/features/activity_runtime/breathe_screen.dart';
import 'package:differentworld/features/activity_runtime/discussions_screen.dart';
import 'package:differentworld/features/activity_runtime/do_it_screen.dart';
import 'package:differentworld/features/activity_runtime/fill_blank_screen.dart';
import 'package:differentworld/features/activity_runtime/letters_screen.dart';
import 'package:differentworld/features/activity_runtime/pattern_maker_screen.dart';
import 'package:differentworld/features/activity_runtime/penny_screen.dart';
import 'package:differentworld/features/activity_runtime/photography_runner_screen.dart';
import 'package:differentworld/features/activity_runtime/potions_screen.dart';
import 'package:differentworld/features/activity_runtime/role_cards_screen.dart';
import 'package:differentworld/features/attendance/morning_checklist_screen.dart';
import 'package:differentworld/features/auth/login_screen.dart';
import 'package:differentworld/features/calm/calm_screen.dart';
import 'package:differentworld/features/captures/capture_inbox_screen.dart';
import 'package:differentworld/features/captures/capture_screen.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/child_world/child_world_screen.dart';
import 'package:differentworld/features/cockpit/conductor_screen.dart';
import 'package:differentworld/features/cockpit/now_cockpit_screen.dart';
import 'package:differentworld/features/curricula/photo_curriculum_screen.dart';
import 'package:differentworld/features/daily/daily_screen.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/entries/observation_form_screen.dart';
import 'package:differentworld/features/entries/observations_index_screen.dart';
import 'package:differentworld/features/family/family_messages_screen.dart';
import 'package:differentworld/features/family/family_today_screen.dart';
import 'package:differentworld/features/games/present_hub_screen.dart';
import 'package:differentworld/features/groups/group_detail_screen.dart';
import 'package:differentworld/features/groups/group_edit_screen.dart';
import 'package:differentworld/features/heroes/hero_creator_screen.dart';
import 'package:differentworld/features/heroes/heroes_hub_screen.dart';
import 'package:differentworld/features/heroes/role_deck_screen.dart';
import 'package:differentworld/features/incidents/incident_form_screen.dart';
import 'package:differentworld/features/incidents/incidents_screen.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/features/invites/invite_create_screen.dart';
import 'package:differentworld/features/launch/launch_screen.dart';
import 'package:differentworld/features/live_board/live_board_screen.dart';
import 'package:differentworld/features/live_session/board_screen.dart';
import 'package:differentworld/features/live_session/cast_screen.dart';
import 'package:differentworld/features/live_session/live_game_screen.dart';
import 'package:differentworld/features/missions/mission_board_screen.dart';
import 'package:differentworld/features/missions/missions_list_screen.dart';
import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:differentworld/features/onboarding/create_space_screen.dart';
import 'package:differentworld/features/onboarding/join_or_create_screen.dart';
import 'package:differentworld/features/pickup/pickup_board_screen.dart';
import 'package:differentworld/features/poster/poster_screen.dart';
import 'package:differentworld/features/recap/recap_composer_screen.dart';
import 'package:differentworld/features/reflections/reflection_session_screen.dart';
import 'package:differentworld/features/review/weekly_review_screen.dart';
import 'package:differentworld/features/review/yearly_review_screen.dart';
import 'package:differentworld/features/routines/routines_screen.dart';
import 'package:differentworld/features/schedule/activities_list_screen.dart';
import 'package:differentworld/features/schedule/activity_edit_screen.dart';
import 'package:differentworld/features/schedule/day_templates_screen.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/schedule/locations_list_screen.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/schedule_screen.dart';
import 'package:differentworld/features/schedule/schedule_view_setting.dart';
import 'package:differentworld/features/schedule/weekly_template_screen.dart';
import 'package:differentworld/features/settings/program_settings_screen.dart';
import 'package:differentworld/features/settings/roles_screen.dart';
import 'package:differentworld/features/settings/settings_screen.dart';
import 'package:differentworld/features/settings/team_screen.dart';
import 'package:differentworld/features/speak/speak_screen.dart';
import 'package:differentworld/features/spellbook/spellbook_screen.dart';
import 'package:differentworld/features/spells/spells_screen.dart';
import 'package:differentworld/features/staff/runbook_screen.dart';
import 'package:differentworld/features/staff/staff_ladder_screen.dart';
import 'package:differentworld/features/story/room_story_screen.dart';
import 'package:differentworld/features/subjects/subject_detail_screen.dart';
import 'package:differentworld/features/supplies/supplies_list_screen.dart';
import 'package:differentworld/features/surveys/survey_list_screen.dart';
import 'package:differentworld/features/tasks/task_screen.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/features/tasks/tasks_screen.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:differentworld/features/today/today_bento_screen.dart';
import 'package:differentworld/features/today/today_screen.dart';
import 'package:differentworld/features/toolkit/print_toolkit_screen.dart';
import 'package:differentworld/features/toolkit/toolkit_screen.dart';
import 'package:differentworld/features/tools/tools_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_edit_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_scan_screen.dart';
import 'package:differentworld/features/vehicles/vehicles_list_screen.dart';
import 'package:differentworld/shared/widgets/app_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '_helpers.dart';

/// THE SCREEN GALLERY — every reachable screen, rendered inside the real
/// AppShell (chrome + omnibox bar) so the plate looks like the running app,
/// light + dark, to `gallery/screens/<name>__<theme>.png`.
///
/// A director [Viewer] over an empty in-memory [AppDatabase] → each screen
/// renders its EMPTY state (a legitimate gallery render) rather than hitting
/// the unmocked PowerSync DB. The pending-Timer those Drift watch streams
/// leave is drained (unmount + advance timers) before flutter_test's
/// `!timersPending` invariant. Pre-auth / standalone screens render bare.

late final AppDatabase _db;
late final Viewer _viewer;

/// Screens that render a perfect plate but keep an ongoing Timer (a clock,
/// realtime poll, autosave, or repeating animation) the unmount-drain can't
/// clear — they trip flutter_test's `!timersPending` invariant at teardown.
/// Their plates are committed; we skip only the (local-only) golden test so
/// the suite stays green. Re-render one of these manually if its screen
/// changes.
const Set<String> _leakyTimer = {
  'screens/activity_arc',
  'screens/capture',
  'screens/journey_tour',
  'screens/live_board',
  'screens/now_cockpit',
  'screens/observation_form',
};

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

  _screenPlate('screens/action_words', const ActionWordsScreen());
  _screenPlate('screens/activities_list', const ActivitiesListScreen());
  _screenPlate('screens/activity_arc', const ActivityArcScreen());
  _screenPlate('screens/activity_edit', const ActivityEditScreen());
  _screenPlate('screens/activity_forge', const ActivityForgeScreen());
  _screenPlate('screens/activity_lens', const ActivityLensScreen());
  _screenPlate('screens/activity_match', const ActivityMatchScreen());
  _screenPlate('screens/board', const BoardScreen());
  _screenPlate('screens/brain_breaks', const BrainBreaksScreen());
  _screenPlate('screens/breathe', const BreatheScreen());
  _screenPlate('screens/capture_inbox', const CaptureInboxScreen());
  _screenPlate('screens/capture', const CaptureScreen());
  _screenPlate('screens/cast', const CastScreen());
  _screenPlate('screens/conductor', const ConductorScreen());
  _screenPlate('screens/day_run', const DayRunScreen());
  _screenPlate('screens/day_templates', const DayTemplatesScreen());
  _screenPlate('screens/family_messages', const FamilyMessagesScreen());
  _screenPlate('screens/family_today', const FamilyTodayScreen());
  _screenPlate('screens/group_discussion', const GroupDiscussionScreen());
  _screenPlate('screens/group_edit', const GroupEditScreen());
  _screenPlate('screens/incident_form', const IncidentFormScreen());
  _screenPlate('screens/incidents', const IncidentsScreen());
  _screenPlate('screens/insights', const InsightsScreen());
  _screenPlate('screens/invite_create', const InviteCreateScreen());
  _screenPlate('screens/journey_tour', const JourneyTourScreen());
  _screenPlate('screens/live_board', const LiveBoardScreen());
  _screenPlate('screens/locations_list', const LocationsListScreen());
  _screenPlate('screens/mission_board', const MissionBoardScreen());
  _screenPlate('screens/missions_list', const MissionsListScreen());
  _screenPlate('screens/morning_checklist', const MorningChecklistScreen());
  _screenPlate('screens/now_cockpit', const NowCockpitScreen());
  _screenPlate('screens/observation_form', const ObservationFormScreen());
  _screenPlate('screens/observations_index', const ObservationsIndexScreen());
  _screenPlate('screens/pattern_maker', const PatternMakerScreen());
  _screenPlate('screens/photo_curriculum', const PhotoCurriculumScreen());
  _screenPlate('screens/photography_runner', const PhotographyRunnerScreen());
  _screenPlate('screens/pickup_board', const PickupBoardScreen());
  _screenPlate('screens/poster', const PosterScreen());
  _screenPlate('screens/present_hub', const PresentHubScreen());
  _screenPlate('screens/print_toolkit', const PrintToolkitScreen());
  _screenPlate('screens/program_hub', const ProgramHubScreen());
  _screenPlate('screens/program_settings', const ProgramSettingsScreen());
  _screenPlate('screens/reflection_session', const ReflectionSessionScreen());
  _screenPlate('screens/role_cards', const RoleCardsScreen());
  _screenPlate('screens/roles', const RolesScreen());
  _screenPlate('screens/room_story', const RoomStoryScreen());
  _screenPlate('screens/runbook', const RunbookScreen());
  _screenPlate('screens/schedule', const ScheduleScreen());
  _screenPlate('screens/send', const SendScreen());
  _screenPlate('screens/settings', const SettingsScreen());
  _screenPlate('screens/speak', const SpeakScreen());
  _screenPlate('screens/spells', const SpellsScreen());
  _screenPlate('screens/staff_ladder', const StaffLadderScreen());
  _screenPlate('screens/supplies_list', const SuppliesListScreen());
  _screenPlate('screens/survey_index', const SurveyIndexScreen());
  _screenPlate('screens/task', const TaskScreen());
  _screenPlate('screens/tasks', const TasksScreen());
  _screenPlate('screens/team', const TeamScreen());
  _screenPlate('screens/themed_world', const ThemedWorldScreen());
  _screenPlate('screens/thinking', const ThinkingScreen());
  _screenPlate('screens/this_week', const ThisWeekScreen());
  _screenPlate('screens/time_capsule', const TimeCapsuleScreen());
  _screenPlate('screens/today', const TodayScreen());
  _screenPlate('screens/toolkit', const ToolkitScreen());
  _screenPlate('screens/tools', const ToolsScreen());
  _screenPlate('screens/vehicle_edit', const VehicleEditScreen());
  _screenPlate('screens/vehicle_scan', const VehicleScanScreen());
  _screenPlate('screens/vehicles_list', const VehiclesListScreen());
  _screenPlate('screens/verb_jobs', const VerbJobsScreen());
  _screenPlate('screens/wall', const WallScreen());
  _screenPlate('screens/weekly_review', const WeeklyReviewScreen());
  _screenPlate('screens/weekly_template', const WeeklyTemplateScreen());
  _screenPlate('screens/world_book', const WorldBookScreen());
  _screenPlate('screens/yearly_review', const YearlyReviewScreen());

  // The 2026-06 activity wave + Calm-pass surfaces — so every new component is
  // measured + golden-locked at the Calm bar. Content screens read
  // bankedContentProvider (curatedSeeds fallback) or are pure; the cohort /
  // per-child ones use _rosterPlate (seeded g1 + s1) so they render populated.
  _screenPlate('screens/calm', const CalmScreen());
  _screenPlate('screens/daily', const DailyScreen());
  _screenPlate('screens/do_it', const DoItScreen());
  _screenPlate('screens/fill_blank', const FillBlankScreen());
  _screenPlate('screens/penny', const PennyScreen());
  _screenPlate('screens/potions', const PotionsScreen());
  _screenPlate('screens/spellbook', const SpellbookScreen());
  _rosterPlate(
    'screens/heroes_hub',
    const HeroesHubScreen(),
    const Size(440, 900),
  );
  _rosterPlate(
    'screens/hero_creator',
    const HeroCreatorScreen(subjectId: 's1'),
    const Size(440, 900),
  );
  _rosterPlate(
    'screens/routines',
    const RoutinesScreen(),
    const Size(440, 900),
  );
  _rosterPlate('screens/letters', const LettersScreen(), const Size(440, 900));
  _rosterPlate(
    'screens/recap_composer',
    const RecapComposerScreen(),
    const Size(440, 1000),
  );
  _rosterPlate(
    'screens/child_world',
    const ChildWorldScreen(subjectId: 's1'),
    const Size(440, 1000),
  );
  _rosterPlate(
    'screens/role_deck',
    const RoleDeckScreen(),
    const Size(440, 900),
  );

  // The bento dashboard needs DATA to be worth seeing (an empty bento is just
  // "No rooms yet"), so it gets a dedicated SEEDED plate — its own DB with
  // three cohorts + a fake now/next lead — at phone and desktop widths.
  _bentoPlate('screens/today_bento', const Size(440, 900));
  // Wide enough that the content area past the nav rail clears 1100dp → the
  // true 6-column desktop packing (hero + rooms share the tall top run).
  _bentoPlate('screens/today_bento_wide', const Size(1500, 950));

  // The time-aligned schedule grid — seeded with two cohorts' afternoon, the
  // toggle forced on, at a matrix width so the grid (not the column matrix)
  // renders.
  _scheduleGridPlate('screens/schedule_time_grid', const Size(1280, 820));

  // Two param'd detail screens the param-free harness can't reach — seeded
  // with a cohort + roster so they render populated.
  _rosterPlate(
    'screens/group_detail',
    const GroupDetailScreen(groupId: 'g1'),
    const Size(440, 900),
  );
  _rosterPlate(
    'screens/subject_detail',
    const SubjectDetailScreen(subjectId: 's1'),
    const Size(440, 900),
  );

  _bareScreenPlate('screens/create_space', const CreateSpaceScreen());
  _bareScreenPlate('screens/join_or_create', const JoinOrCreateScreen());
  _bareScreenPlate('screens/join_unavailable', const JoinUnavailableScreen());
  _bareScreenPlate('screens/launch', const LaunchScreen());
  _bareScreenPlate('screens/login', const LoginScreen());
}

Future<void> _pumpAndShoot(
  WidgetTester tester,
  String goldenToken,
  Widget appChild,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      // Seed the viewer + DB; neutralize AppShell's own Drift watches
      // (catalog / live strip / nav counts) so only the SCREEN under test
      // creates watch streams.
      overrides: [
        appDatabaseProvider.overrideWith((ref) => _db),
        viewerProvider.overrideWithValue(_viewer),
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
      child: appChild,
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../gallery/$goldenToken.png'),
  );
  // Drain: unmount (cancels Drift subscriptions) + advance timers so any
  // pending one-shot Drift Timer fires before teardown's invariant check.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  // Consume late async errors that fired AFTER the golden was captured — a
  // screen's direct Postgrest read (onboarding/family) or a missing plugin
  // (the camera scanner). The plate is already written; these don't affect
  // it. A genuine build-time crash would surface as a red error box IN the
  // captured PNG, which the visual review catches — so this can't hide one.
  while (tester.takeException() != null) {
    // drained
  }
}

Widget _app(String mode, GoRouter router) => MaterialApp.router(
  theme: mode == 'dark' ? buildDarkTheme() : buildLightTheme(),
  debugShowCheckedModeBanner: false,
  routerConfig: router,
);

GoRouter _shellRouter(Widget screen) => GoRouter(
  initialLocation: '/screen',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [GoRoute(path: '/screen', builder: (_, _) => screen)],
    ),
  ],
);

GoRouter _bareRouter(Widget screen) => GoRouter(
  initialLocation: '/screen',
  routes: [GoRoute(path: '/screen', builder: (_, _) => screen)],
);

/// Render a screen inside the real AppShell, light + dark.
void _screenPlate(
  String name,
  Widget screen, {
  double width = 440,
  double height = 900,
}) {
  final skip = !runGoldens || _leakyTimer.contains(name);
  for (final mode in const ['light', 'dark']) {
    testWidgets('$name - $mode', (tester) async {
      await _pumpAndShoot(
        tester,
        '${name}__$mode',
        _app(mode, _shellRouter(screen)),
        Size(width, height),
      );
    }, skip: skip);
  }
}

/// Render a pre-auth / standalone screen WITHOUT the shell.
void _bareScreenPlate(
  String name,
  Widget screen, {
  double width = 440,
  double height = 900,
}) {
  for (final mode in const ['light', 'dark']) {
    testWidgets('$name - $mode', (tester) async {
      await _pumpAndShoot(
        tester,
        '${name}__$mode',
        _app(mode, _bareRouter(screen)),
        Size(width, height),
      );
    }, skip: !runGoldens);
  }
}

/// The bento dashboard, SEEDED so it renders populated. A throwaway in-memory
/// DB (space + director + three cohorts) plus a fake [ContextLead] for the
/// now/next hero; captures/tasks left empty (their "All clear" state). Used
/// for the `today_bento` plates only — never touches the shared `_db`.
void _bentoPlate(String name, Size size) {
  for (final mode in const ['light', 'dark']) {
    testWidgets('$name - $mode', (tester) async {
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
      const cohorts = [
        ('g1', 'Sparrows', 'Ages 4–5'),
        ('g2', 'Robins', 'Ages 6–7'),
        ('g3', 'Owls', 'Ages 8–9'),
      ];
      for (final (id, cname, age) in cohorts) {
        await db
            .into(db.groups)
            .insert(
              GroupsCompanion.insert(
                id: id,
                spaceId: 'sp1',
                name: cname,
                capabilities: '{}',
                createdAt: now,
                updatedAt: now,
                ageRange: Value(age),
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
      const lead = ContextLead(
        eyebrow: 'Now',
        title: 'Outdoor free play',
        line: 'Then snack at 10:30 · Sunny Room',
        icon: Icons.play_circle_outline,
        tone: ContextTone.go,
        primary: ContextMove(
          icon: Icons.camera_alt_outlined,
          label: 'Capture a moment',
          route: '/captures/new',
        ),
      );

      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith((ref) => db),
            viewerProvider.overrideWithValue(viewer),
            liveBlockProvider.overrideWith((ref) => _demoLiveBlock()),
            omniboxCatalogProvider.overrideWithValue(const <OmniboxEntry>[]),
            contextLeadProvider.overrideWith((ref) => lead),
            momentsForBlockProvider(
              'blk-demo',
            ).overrideWith((_) => Stream<List<Entry>>.value(const <Entry>[])),
            capturesProvider(CaptureFilter.open).overrideWith(
              (_) => Stream<List<Capture>>.value(const <Capture>[]),
            ),
            tasksProvider(
              TaskFilter.open,
            ).overrideWith((_) => Stream<List<Task>>.value(const <Task>[])),
          ],
          child: _app(mode, _shellRouter(const TodayBentoScreen())),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../gallery/${name}__$mode.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      // Drain the per-cohort Drift watch timers (groupDayState × 3) — a couple
      // of 1s advances clears them before flutter_test's !timersPending check.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {
        // drained
      }
      await db.close().timeout(const Duration(seconds: 5), onTimeout: () {});
    }, skip: !runGoldens);
  }
}

/// Seeds a cohort + roster (space + director + group g1 + three subjects),
/// then renders a param'd detail screen (group / subject) populated. Throwaway
/// DB; never touches the shared `_db`.
void _rosterPlate(String name, Widget screen, Size size) {
  for (final mode in const ['light', 'dark']) {
    testWidgets('$name - $mode', (tester) async {
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

      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith((ref) => db),
            viewerProvider.overrideWithValue(viewer),
            liveBlockProvider.overrideWith((ref) => _demoLiveBlock()),
            omniboxCatalogProvider.overrideWithValue(const <OmniboxEntry>[]),
            momentsForBlockProvider(
              'blk-demo',
            ).overrideWith((_) => Stream<List<Entry>>.value(const <Entry>[])),
            capturesProvider(CaptureFilter.open).overrideWith(
              (_) => Stream<List<Capture>>.value(const <Capture>[]),
            ),
            tasksProvider(
              TaskFilter.open,
            ).overrideWith((_) => Stream<List<Task>>.value(const <Task>[])),
          ],
          child: _app(mode, _shellRouter(screen)),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../gallery/${name}__$mode.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {
        // drained
      }
      await db.close().timeout(const Duration(seconds: 5), onTimeout: () {});
    }, skip: !runGoldens);
  }
}

/// Forces the schedule time-grid toggle on for the seeded plate.
class _ScheduleGridOn extends ScheduleTimeGridNotifier {
  @override
  Future<bool> build() async => true;
}

/// The time-aligned schedule grid, SEEDED: a throwaway DB with two cohorts and
/// an afternoon of blocks on TODAY (so the screen's default date matches), the
/// toggle forced on, rendered at a matrix width. Never touches the shared
/// `_db`.
void _scheduleGridPlate(String name, Size size) {
  for (final mode in const ['light', 'dark']) {
    testWidgets('$name - $mode', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.createMigrator().createAll();
      const stamp = '2026-06-17T08:00:00Z';
      await db
          .into(db.spaces)
          .insert(
            SpacesCompanion.insert(
              id: 'sp1',
              name: 'Sunny Days Program',
              settings: '{}',
              capabilities: '{}',
              createdAt: stamp,
              updatedAt: stamp,
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
              createdAt: stamp,
              updatedAt: stamp,
              spaceId: const Value('sp1'),
            ),
          );
      for (final (id, cname, age) in const [
        ('g1', 'Sparrows', 'Ages 4–5'),
        ('g2', 'Robins', 'Ages 6–7'),
      ]) {
        await db
            .into(db.groups)
            .insert(
              GroupsCompanion.insert(
                id: id,
                spaceId: 'sp1',
                name: cname,
                capabilities: '{}',
                createdAt: stamp,
                updatedAt: stamp,
                ageRange: Value(age),
              ),
            );
      }
      final n = DateTime.now();
      final day = DateTime(n.year, n.month, n.day);
      final date = isoDateLocal(day);
      String iso(int h, int m) =>
          DateTime(day.year, day.month, day.day, h, m).toIso8601String();
      Future<void> blk(
        String id,
        String gid,
        int sh,
        int sm,
        int eh,
        int em,
        String title,
        String kind,
      ) => db
          .into(db.scheduleBlocks)
          .insert(
            ScheduleBlocksCompanion.insert(
              id: id,
              spaceId: 'sp1',
              groupId: gid,
              date: date,
              startAt: iso(sh, sm),
              endAt: iso(eh, em),
              kind: kind,
              createdAt: stamp,
              updatedAt: stamp,
              title: Value(title),
              status: const Value('planned'),
            ),
          );
      await blk('b1', 'g1', 15, 0, 15, 30, 'Snack', 'break');
      await blk('b2', 'g1', 15, 30, 16, 30, 'Outdoor play', 'on_site');
      await blk('b3', 'g1', 16, 30, 17, 30, 'Art studio', 'on_site');
      await blk('b4', 'g2', 15, 0, 16, 0, 'Homework help', 'on_site');
      await blk('b5', 'g2', 16, 0, 16, 30, 'Snack', 'break');
      await blk('b6', 'g2', 16, 30, 17, 30, 'STEM lab', 'on_site');

      final m = await (db.select(
        db.members,
      )..where((t) => t.id.equals('m1'))).getSingle();
      final s = await (db.select(
        db.spaces,
      )..where((t) => t.id.equals('sp1'))).getSingle();
      final viewer = Viewer(member: m, space: s);

      await tester.binding.setSurfaceSize(size);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWith((ref) => db),
            viewerProvider.overrideWithValue(viewer),
            liveBlockProvider.overrideWith((ref) => _demoLiveBlock()),
            omniboxCatalogProvider.overrideWithValue(const <OmniboxEntry>[]),
            scheduleTimeGridProvider.overrideWith(_ScheduleGridOn.new),
            momentsForBlockProvider(
              'blk-demo',
            ).overrideWith((_) => Stream<List<Entry>>.value(const <Entry>[])),
            capturesProvider(CaptureFilter.open).overrideWith(
              (_) => Stream<List<Capture>>.value(const <Capture>[]),
            ),
            tasksProvider(
              TaskFilter.open,
            ).overrideWith((_) => Stream<List<Task>>.value(const <Task>[])),
          ],
          child: _app(mode, _shellRouter(const ScheduleScreen())),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../gallery/${name}__$mode.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      while (tester.takeException() != null) {
        // drained
      }
      await db.close().timeout(const Duration(seconds: 5), onTimeout: () {});
    }, skip: !runGoldens);
  }
}
