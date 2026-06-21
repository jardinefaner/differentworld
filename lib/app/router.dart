import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart'
    show Entry, Export, Invite, Mission, Subject;
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/action_words_kid_screen.dart';
import 'package:differentworld/features/action_words/action_words_screen.dart';
import 'package:differentworld/features/action_words/activity_arc_screen.dart';
import 'package:differentworld/features/action_words/activity_match_screen.dart';
import 'package:differentworld/features/action_words/book_screen.dart';
import 'package:differentworld/features/action_words/collection_screen.dart';
import 'package:differentworld/features/action_words/day_run_screen.dart';
import 'package:differentworld/features/action_words/growth_arc_screen.dart';
import 'package:differentworld/features/action_words/journey_tour_screen.dart';
import 'package:differentworld/features/action_words/kid_job_screen.dart';
import 'package:differentworld/features/action_words/program_hub_screen.dart';
import 'package:differentworld/features/action_words/send_screen.dart';
import 'package:differentworld/features/action_words/themed_world_screen.dart';
import 'package:differentworld/features/action_words/thinking_screen.dart';
import 'package:differentworld/features/action_words/this_week_screen.dart';
import 'package:differentworld/features/action_words/time_capsule_screen.dart';
import 'package:differentworld/features/action_words/verb_jobs_screen.dart';
import 'package:differentworld/features/action_words/wall_screen.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:differentworld/features/action_words/widgets/deck_overview.dart';
import 'package:differentworld/features/action_words/world_book_screen.dart';
import 'package:differentworld/features/action_words/world_present_screen.dart';
import 'package:differentworld/features/activity_forge/activity_forge_screen.dart';
import 'package:differentworld/features/activity_forge/activity_lens_screen.dart';
import 'package:differentworld/features/activity_runtime/brain_breaks_screen.dart';
import 'package:differentworld/features/activity_runtime/breathe_screen.dart';
import 'package:differentworld/features/activity_runtime/discussions_screen.dart';
import 'package:differentworld/features/activity_runtime/do_it_screen.dart';
import 'package:differentworld/features/activity_runtime/fill_blank_screen.dart';
import 'package:differentworld/features/activity_runtime/letters_screen.dart';
import 'package:differentworld/features/activity_runtime/math_runner_screen.dart';
import 'package:differentworld/features/activity_runtime/pattern_maker_screen.dart';
import 'package:differentworld/features/activity_runtime/penny_screen.dart';
import 'package:differentworld/features/activity_runtime/photography_runner_screen.dart';
import 'package:differentworld/features/activity_runtime/potions_screen.dart';
import 'package:differentworld/features/activity_runtime/role_capture.dart';
import 'package:differentworld/features/activity_runtime/role_cards_screen.dart';
import 'package:differentworld/features/attendance/attendance_screen.dart';
import 'package:differentworld/features/attendance/morning_checklist_screen.dart';
import 'package:differentworld/features/auth/login_screen.dart';
import 'package:differentworld/features/calm/calm_screen.dart';
import 'package:differentworld/features/captures/capture_inbox_screen.dart';
import 'package:differentworld/features/captures/capture_screen.dart';
import 'package:differentworld/features/child_world/child_world_screen.dart';
import 'package:differentworld/features/cockpit/conductor_screen.dart';
import 'package:differentworld/features/cockpit/now_cockpit_screen.dart';
import 'package:differentworld/features/curricula/photo_curriculum_screen.dart';
import 'package:differentworld/features/daily/daily_screen.dart';
import 'package:differentworld/features/entries/observation_form_screen.dart';
import 'package:differentworld/features/entries/observations_index_screen.dart';
import 'package:differentworld/features/entries/observations_screen.dart';
import 'package:differentworld/features/exports/progress_report_screen.dart';
import 'package:differentworld/features/exports/send_export_screen.dart';
import 'package:differentworld/features/family/family_messages_screen.dart';
import 'package:differentworld/features/family/family_share_screen.dart';
import 'package:differentworld/features/family/family_subject_detail_screen.dart';
import 'package:differentworld/features/family/family_today_screen.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/as_if_game.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/cues_game.dart';
import 'package:differentworld/features/games/games/fact_or_fib_game.dart';
import 'package:differentworld/features/games/games/grid_reveal_game.dart';
import 'package:differentworld/features/games/games/letter_words_game.dart';
import 'package:differentworld/features/games/games/math_quiz_game.dart';
import 'package:differentworld/features/games/games/memory_match_screen.dart';
import 'package:differentworld/features/games/games/name_it_screen.dart';
import 'package:differentworld/features/games/games/nownext_screen.dart';
import 'package:differentworld/features/games/games/odd_one_out_screen.dart';
import 'package:differentworld/features/games/games/picker_screen.dart';
import 'package:differentworld/features/games/games/poll_game.dart';
import 'package:differentworld/features/games/games/rhyme_time_game.dart';
import 'package:differentworld/features/games/games/riddles_game.dart';
import 'package:differentworld/features/games/games/story_starters_game.dart';
import 'package:differentworld/features/games/games/this_or_that_game.dart';
import 'package:differentworld/features/games/games/whats_missing_screen.dart';
import 'package:differentworld/features/games/present_hub_screen.dart';
import 'package:differentworld/features/groups/group_detail_screen.dart';
import 'package:differentworld/features/groups/group_edit_screen.dart';
import 'package:differentworld/features/heroes/hero_creator_screen.dart';
import 'package:differentworld/features/heroes/heroes_hub_screen.dart';
import 'package:differentworld/features/heroes/role_deck_screen.dart';
import 'package:differentworld/features/heroes/role_game_screen.dart';
import 'package:differentworld/features/incidents/incident_form_screen.dart';
import 'package:differentworld/features/incidents/incidents_screen.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:differentworld/features/invites/invite_create_screen.dart';
import 'package:differentworld/features/invites/invite_share_screen.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/launch/launch_screen.dart';
import 'package:differentworld/features/live_board/live_board_screen.dart';
import 'package:differentworld/features/live_session/board_screen.dart';
import 'package:differentworld/features/live_session/cast_screen.dart';
import 'package:differentworld/features/live_session/live_game_screen.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:differentworld/features/messages/message_thread_screen.dart';
import 'package:differentworld/features/missions/mission_board_screen.dart';
import 'package:differentworld/features/missions/mission_do_screen.dart';
import 'package:differentworld/features/missions/missions_list_screen.dart';
import 'package:differentworld/features/omnibox/omnibox_search_screen.dart';
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
import 'package:differentworld/features/schedule/block_edit_screen.dart';
import 'package:differentworld/features/schedule/block_present_screen.dart';
import 'package:differentworld/features/schedule/day_template_editor_screen.dart';
import 'package:differentworld/features/schedule/day_templates_screen.dart';
import 'package:differentworld/features/schedule/locations_list_screen.dart';
import 'package:differentworld/features/schedule/schedule_screen.dart';
import 'package:differentworld/features/schedule/trip_detail_screen.dart';
import 'package:differentworld/features/schedule/weekly_template_screen.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/settings/cockpit_home_setting.dart';
import 'package:differentworld/features/settings/member_detail_screen.dart';
import 'package:differentworld/features/settings/program_settings_screen.dart';
import 'package:differentworld/features/settings/roles_screen.dart';
import 'package:differentworld/features/settings/settings_screen.dart';
import 'package:differentworld/features/settings/team_screen.dart';
import 'package:differentworld/features/speak/speak_screen.dart';
import 'package:differentworld/features/spellbook/spellbook_screen.dart';
import 'package:differentworld/features/spells/spells_screen.dart';
import 'package:differentworld/features/staff/runbook_screen.dart';
import 'package:differentworld/features/staff/staff_ladder_screen.dart';
import 'package:differentworld/features/story/kid_story_screen.dart';
import 'package:differentworld/features/story/room_story_screen.dart';
import 'package:differentworld/features/story/story_showcase_screen.dart';
import 'package:differentworld/features/subjects/child_trail_screen.dart';
import 'package:differentworld/features/subjects/health_profile_screen.dart';
import 'package:differentworld/features/subjects/subject_detail_screen.dart';
import 'package:differentworld/features/subjects/subject_edit_screen.dart';
import 'package:differentworld/features/supplies/supplies_list_screen.dart';
import 'package:differentworld/features/surveys/survey_list_screen.dart';
import 'package:differentworld/features/surveys/survey_table_screen.dart';
import 'package:differentworld/features/surveys/survey_take_screen.dart';
import 'package:differentworld/features/tasks/task_screen.dart';
import 'package:differentworld/features/tasks/tasks_screen.dart';
import 'package:differentworld/features/today/bento_home_setting.dart';
import 'package:differentworld/features/today/child_day_screen.dart';
import 'package:differentworld/features/today/today_bento_screen.dart';
import 'package:differentworld/features/today/today_screen.dart';
import 'package:differentworld/features/toolkit/print_toolkit_screen.dart';
import 'package:differentworld/features/toolkit/toolkit_screen.dart';
import 'package:differentworld/features/toolkit/toolkit_tool_screen.dart';
import 'package:differentworld/features/tools/tools_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_deep_link.dart';
import 'package:differentworld/features/vehicles/vehicle_detail_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_edit_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_inspection_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_photo_shots_edit_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_scan_screen.dart';
import 'package:differentworld/features/vehicles/vehicles_list_screen.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart'
    show VehicleLogKind;
import 'package:differentworld/features/world/character_sheet_screen.dart';
import 'package:differentworld/features/world/draw_self_screen.dart';
import 'package:differentworld/shared/widgets/app_shell.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/route_title.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final refresh = _RouterAuthRefresh(supabase.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    // Wave 111: friendly 404 instead of go_router's default red error
    // frame when a user types or follows a stale URL. Wrapped in
    // RouteTitle so the browser tab also reflects the state.
    errorBuilder: (context, state) => RouteTitle(
      title: 'Page not found',
      child: _NotFoundScreen(uri: state.uri.toString()),
    ),
    redirect: (context, state) {
      final isSignedIn = ref.read(isSignedInProvider);
      final goingToAuth = state.matchedLocation.startsWith('/login');
      if (!isSignedIn && !goingToAuth) return '/login';
      if (isSignedIn && goingToAuth) return '/';
      // Guardian gating: family-lens users have no business on the
      // staff-side surfaces (settings, schedule, captures, tasks,
      // observations, etc.). Bounce them back to /. The router uses
      // `_Home` which auto-resolves the family path for guardians via
      // viewerProvider, so / is always the right destination. Only
      // routes meant for the family lens are allowed through.
      final viewer = ref.read(viewerProvider);
      if (viewer is GuardianViewer) {
        final loc = state.matchedLocation;
        const familyAllowed = <String>[
          '/',
          '/messages',
          '/children',
          '/share-home',
        ];
        final allowed = familyAllowed.any(
          (prefix) => loc == prefix || loc.startsWith('$prefix/'),
        );
        if (!allowed) return '/';
      }
      // Wave 106: kid-mode pin. When a kid-launchable surface
      // (survey-take today; kid-journal in the future) sets
      // `kidModeLockedRouteProvider`, the router refuses to leave
      // that URL. PopScope.canPop catches Flutter Navigator pops;
      // THIS catches the web browser back button (which calls
      // `window.history.back()` directly and bypasses PopScope).
      // Once the staff exit dance completes, the surface's dispose
      // clears the locked route, and navigation resumes normally.
      final lockedRoute = ref.read(kidModeLockedRouteProvider);
      if (lockedRoute != null && state.matchedLocation != lockedRoute) {
        return lockedRoute;
      }
      return null;
    },
    routes: [
      // Persistent app shell wraps every route — the bottom omnibox
      // bar lives in the shell, so it stays mounted across page
      // transitions. Login + JoinOrCreate ride inside the shell too
      // (user said the bar should be everywhere; the catalog is just
      // empty pre-auth so the bar shows but search returns nothing).
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const RouteTitle(title: 'Today', child: _Home()),
            routes: [
              GoRoute(
                path: 'checklist',
                builder: (_, state) => RouteTitle(
                  title: 'Morning checklist',
                  child: MorningChecklistScreen(
                    initialFilter: state.uri.queryParameters['filter'],
                  ),
                ),
              ),
              GoRoute(
                path: 'pickup',
                builder: (_, _) => const RouteTitle(
                  title: 'Pickup',
                  child: PickupBoardScreen(),
                ),
              ),
              GoRoute(
                path: 'now',
                builder: (_, _) => const RouteTitle(
                  title: 'Now',
                  child: NowCockpitScreen(),
                ),
              ),
              GoRoute(
                path: 'conductor',
                builder: (_, _) => const RouteTitle(
                  title: 'Conductor',
                  child: ConductorScreen(),
                ),
              ),
              // Today, always reachable by name — the curiosity bar links here
              // when the cockpit has taken over the home slot (COCKPIT.md s4).
              GoRoute(
                path: 'today',
                builder: (_, _) => const RouteTitle(
                  title: 'Today',
                  child: TodayScreen(),
                ),
              ),
              GoRoute(
                path: 'action-words',
                builder: (_, _) => const RouteTitle(
                  title: 'Action Words',
                  child: ActionWordsScreen(),
                ),
                routes: [
                  // Static path BEFORE the :subjectId param route, so
                  // /action-words/send doesn't match as a subject id.
                  GoRoute(
                    path: 'send',
                    builder: (_, _) => const RouteTitle(
                      title: 'Send home',
                      child: SendScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'worlds',
                    builder: (_, _) => const RouteTitle(
                      title: 'Our worlds',
                      child: WorldBookScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'different-worlds',
                    builder: (_, _) => const RouteTitle(
                      title: 'Different Worlds',
                      child: ThemedWorldScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'activities',
                    builder: (_, state) {
                      final raw = state.uri.queryParameters['verbs'] ?? '';
                      final verbs = raw.isEmpty
                          ? const <String>[]
                          : raw.split(',').where((s) => s.isNotEmpty).toList();
                      return RouteTitle(
                        title: 'Activities',
                        child: ActivityMatchScreen(initialVerbs: verbs),
                      );
                    },
                  ),
                  // The kid-facing pick (3 segments) — placed BEFORE the
                  // 1-segment :subjectId so '/action-words/pick/<id>' resolves
                  // here, not as a child id. Locks into kid mode on mount.
                  GoRoute(
                    path: 'pick/:subjectId',
                    builder: (_, state) => RouteTitle(
                      title: 'Pick your words',
                      child: ActionWordsKidScreen(
                        subjectId: state.pathParameters['subjectId']!,
                      ),
                    ),
                  ),
                  // Role-4: the kid's verb-jobs for the day, kid-mode locked.
                  // 3 segments so it resolves here, not as a :subjectId.
                  GoRoute(
                    path: 'job/:subjectId',
                    builder: (_, state) => RouteTitle(
                      title: 'My jobs',
                      child: KidJobScreen(
                        subjectId: state.pathParameters['subjectId']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':subjectId',
                    builder: (_, state) => RouteTitle(
                      title: 'Collection',
                      child: CollectionScreen(
                        subjectId: state.pathParameters['subjectId']!,
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'groups/new',
                builder: (_, _) => const RouteTitle(
                  title: 'New classroom',
                  child: GroupEditScreen(),
                ),
              ),
              GoRoute(
                path: 'groups/:id',
                // Dynamic title (group name) is set INSIDE GroupDetailScreen
                // — see its build method. Same pattern for student detail
                // and member detail below.
                builder: (_, state) => GroupDetailScreen(
                  groupId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => RouteTitle(
                      title: 'Edit classroom',
                      child: GroupEditScreen(
                        groupId: state.pathParameters['id'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'attendance',
                    builder: (_, state) => RouteTitle(
                      title: 'Attendance',
                      child: AttendanceScreen(
                        groupId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'observations',
                    builder: (_, state) => RouteTitle(
                      title: 'Observations',
                      child: ObservationsScreen(
                        groupId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'students/new',
                    builder: (_, state) => RouteTitle(
                      title: 'New student',
                      child: SubjectEditScreen(
                        groupId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'students/:sid',
                    // Dynamic title set in SubjectDetailScreen.
                    builder: (_, state) => SubjectDetailScreen(
                      subjectId: state.pathParameters['sid']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => RouteTitle(
                          title: 'Edit student',
                          child: SubjectEditScreen(
                            groupId: state.pathParameters['id']!,
                            subjectId: state.pathParameters['sid'],
                          ),
                        ),
                      ),
                      // Progress-report PDF — preview + share/print.
                      // Reached from the staff subject detail screen.
                      GoRoute(
                        path: 'progress-report',
                        builder: (_, state) => RouteTitle(
                          title: 'Progress report',
                          child: ProgressReportScreen(
                            subjectId: state.pathParameters['sid']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Top-level observations index — every observation the
              // viewer can see, newest first. See UX_DECISIONS §8.
              GoRoute(
                path: 'observations',
                builder: (_, _) => const RouteTitle(
                  title: 'Observations',
                  child: ObservationsIndexScreen(),
                ),
                routes: [
                  // Create-observation route (Wave 21, replaces the old
                  // `ObservationFormSheet.show`). Query params let the
                  // caller pre-fill groupId + subjectId.
                  GoRoute(
                    path: 'new',
                    builder: (_, state) {
                      final q = state.uri.queryParameters;
                      return RouteTitle(
                        title: 'New observation',
                        child: ObservationFormScreen(
                          groupId: q['groupId'],
                          initialSubjectId: q['subjectId'],
                        ),
                      );
                    },
                  ),
                  // Edit-observation route. The Entry is passed via
                  // go_router `extra` so we don't re-fetch by id (the
                  // caller already has the row in memory).
                  GoRoute(
                    path: ':id/edit',
                    builder: (_, state) {
                      final entry = state.extra;
                      return RouteTitle(
                        title: 'Edit observation',
                        child: ObservationFormScreen(
                          existing: entry is Entry ? entry : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
              // Incident log — structured, exportable incident capture
              // (docs/WORKFLOWS.md gap #3). Reuses entries.kind='incident'.
              GoRoute(
                path: 'incidents',
                builder: (_, state) => RouteTitle(
                  title: 'Incidents',
                  child: IncidentsScreen(
                    initialFilter: state.uri.queryParameters['filter'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, state) => RouteTitle(
                      title: 'Log an incident',
                      child: IncidentFormScreen(
                        initialSubjectId:
                            state.uri.queryParameters['subjectId'],
                      ),
                    ),
                  ),
                ],
              ),
              // Insights — questions surfaced by the upward loop from
              // patterns in existing data (attendance / certs / vehicles
              // / observations / surveys). No new schema; pure derivation.
              GoRoute(
                path: 'insights',
                builder: (_, _) => const RouteTitle(
                  title: 'Insights',
                  child: InsightsScreen(),
                ),
              ),
              // Capture inbox — the upward loop's *input* side. Quick
              // "I noticed…" notes awaiting triage into observations
              // or dismissal.
              GoRoute(
                path: 'captures',
                builder: (_, _) => const RouteTitle(
                  title: 'Captures',
                  child: CaptureInboxScreen(),
                ),
                routes: [
                  // New-capture surface as a real route (Wave 21,
                  // replaces the old `showCaptureSheet` bottom-sheet).
                  GoRoute(
                    path: 'new',
                    builder: (_, _) => const RouteTitle(
                      title: 'New capture',
                      child: CaptureScreen(),
                    ),
                  ),
                ],
              ),
              // Tasks — the third capture-promotion destination, and a
              // standalone to-do list for the program.
              GoRoute(
                path: 'tasks',
                builder: (_, _) => const RouteTitle(
                  title: 'Tasks',
                  child: TasksScreen(),
                ),
                routes: [
                  // New-task surface as a real route (Wave 21,
                  // replaces the old `showNewTaskSheet` bottom-sheet).
                  GoRoute(
                    path: 'new',
                    builder: (_, _) => const RouteTitle(
                      title: 'New task',
                      child: TaskScreen(),
                    ),
                  ),
                ],
              ),
              // Messages — `/messages` is the family-side index (one row
              // per linked child). Threads themselves are reached at
              // `/messages/:subjectId/:guardianId` from either the family
              // index or the staff subject_detail.
              GoRoute(
                path: 'messages',
                builder: (_, _) => const RouteTitle(
                  title: 'Messages',
                  child: FamilyMessagesScreen(),
                ),
              ),
              GoRoute(
                path: 'messages/:subjectId/:guardianId',
                // Dynamic title set in MessageThreadScreen.
                builder: (_, state) => MessageThreadScreen(
                  subjectId: state.pathParameters['subjectId']!,
                  guardianId: state.pathParameters['guardianId']!,
                ),
              ),
              // Share from home — the family-side half of the homework loop
              // (docs/VISION.md 2026-06-19). The parent sends what their child
              // brought; it lands in the child's message thread for staff.
              GoRoute(
                path: 'share-home',
                builder: (_, _) => const RouteTitle(
                  title: 'Share from home',
                  child: FamilyShareScreen(),
                ),
              ),
              // Weekly review — same data as /insights but presented as a
              // guided one-question-per-page flow. The framework's
              // medium-tempo surface.
              GoRoute(
                path: 'review',
                builder: (_, _) => const RouteTitle(
                  title: 'Weekly review',
                  child: WeeklyReviewScreen(),
                ),
                routes: [
                  // Yearly review — the long-tempo Foundation re-grounding.
                  // A calm snapshot + three open-ended prompts; no data to
                  // submit, just orientation.
                  GoRoute(
                    path: 'year',
                    builder: (_, _) => const RouteTitle(
                      title: 'Yearly review',
                      child: YearlyReviewScreen(),
                    ),
                  ),
                ],
              ),
              // Surveys — index of templates + per-template list of kids
              // + take-survey flow.
              GoRoute(
                path: 'surveys',
                builder: (_, _) => const RouteTitle(
                  title: 'Surveys',
                  child: SurveyIndexScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':templateId',
                    // Dynamic title set in SurveyTemplateDetailScreen.
                    builder: (_, state) => SurveyTemplateDetailScreen(
                      templateId: state.pathParameters['templateId']!,
                    ),
                    routes: [
                      // Wave 138: anonymous take. The screen owns the
                      // response id (generated in initState) so the
                      // route itself doesn't carry one — every
                      // navigation to `/surveys/:templateId/take`
                      // starts a fresh session. No resume by design;
                      // the user's "Start a new survey" button always
                      // lands here.
                      GoRoute(
                        path: 'take',
                        builder: (_, state) => SurveyTakeScreen(
                          templateId: state.pathParameters['templateId']!,
                        ),
                      ),
                      // Spreadsheet review across kids — director scans
                      // patterns and exports CSV.
                      GoRoute(
                        path: 'table',
                        builder: (_, state) => RouteTitle(
                          title: 'Survey table',
                          child: SurveyTableScreen(
                            templateId: state.pathParameters['templateId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Family-side direct route: a guardian navigates to a child
              // without going through a classroom they don't see. Renders
              // a read-only family-tailored detail (no admin chrome) —
              // staff hitting their kid's profile use the nested staff
              // route at /groups/:id/students/:sid instead.
              GoRoute(
                path: 'children/:sid',
                // Dynamic title (kid name) set in FamilySubjectDetailScreen.
                builder: (_, state) => FamilySubjectDetailScreen(
                  subjectId: state.pathParameters['sid']!,
                ),
              ),
              // Camp scheduling — staff-facing.
              GoRoute(
                path: 'schedule',
                builder: (_, _) => const RouteTitle(
                  title: 'Schedule',
                  child: ScheduleScreen(),
                ),
              ),
              // Wave 154: weekly template authoring.
              GoRoute(
                path: 'schedule/template',
                builder: (_, _) => const RouteTitle(
                  title: 'Weekly template',
                  child: WeeklyTemplateScreen(),
                ),
              ),
              // Day-template builder: duration-blocks, drag to reorder,
              // apply onto a date → schedule_blocks.
              GoRoute(
                path: 'schedule/day-templates',
                builder: (_, _) => const RouteTitle(
                  title: 'Day templates',
                  child: DayTemplatesScreen(),
                ),
              ),
              GoRoute(
                path: 'schedule/day-templates/:id',
                builder: (_, state) => DayTemplateEditorScreen(
                  templateId: state.pathParameters['id']!,
                ),
              ),
              // Wave 159: trip detail (MVP). One screen per
              // field-trip schedule_block — destination, slips,
              // vehicles. The full multi-step wizard sits on top later.
              GoRoute(
                path: 'trips/:blockId',
                builder: (_, state) => RouteTitle(
                  title: 'Trip details',
                  child: TripDetailScreen(
                    blockId: state.pathParameters['blockId']!,
                  ),
                ),
              ),
              // Block create/edit route (Wave 26, replaces
              // `BlockEditSheet`). Args ride via go_router `extra` as
              // a `BlockEditArgs` record; missing-extra falls back to
              // the schedule screen (the only valid entry path).
              GoRoute(
                path: 'schedule/block',
                builder: (_, state) {
                  final args = state.extra;
                  if (args is! BlockEditArgs) {
                    return const RouteTitle(
                      title: 'Schedule',
                      child: ScheduleScreen(),
                    );
                  }
                  return RouteTitle(
                    title: args.existing == null ? 'New block' : 'Edit block',
                    child: BlockEditScreen(
                      groupId: args.groupId,
                      defaultStart: args.defaultStart,
                      existing: args.existing,
                      prefillCurriculumSlug: args.prefillCurriculumSlug,
                    ),
                  );
                },
              ),
              // Send-export route (Wave 25, replaces
              // `showSendExportSheet`). Export passed via `extra`;
              // missing-extra falls back to a small error screen.
              GoRoute(
                path: 'exports/:id/send',
                builder: (_, state) {
                  final export = state.extra;
                  if (export is! Export) {
                    return const _MissingExportScreen();
                  }
                  return RouteTitle(
                    title: 'Send report',
                    child: SendExportScreen(export: export),
                  );
                },
              ),
              // Subject health profile (Wave 27, replaces
              // `HealthProfileSheet`). Subject passed via `extra`.
              GoRoute(
                path: 'subjects/:id/health',
                builder: (_, state) {
                  final subject = state.extra;
                  if (subject is! Subject) {
                    return const _MissingSubjectScreen();
                  }
                  return RouteTitle(
                    title: 'Health profile',
                    child: HealthProfileScreen(subject: subject),
                  );
                },
              ),
              // Different World — the persistent in-world self (docs/WORLD.md).
              // Both build from the path id alone so a kid-mode bounce-back
              // (which drops `extra`) rebuilds cleanly.
              GoRoute(
                path: 'subjects/:id/me',
                builder: (_, state) => RouteTitle(
                  title: 'World self',
                  child: CharacterSheetScreen(
                    subjectId: state.pathParameters['id']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'subjects/:id/draw',
                builder: (_, state) => DrawSelfScreen(
                  subjectId: state.pathParameters['id']!,
                  displayName: state.extra as String?,
                ),
              ),
              // Heroes — the per-child make-believe alter-ego creator
              // (docs/VISION.md 2026-06-19). Reached from the Heroes hub.
              GoRoute(
                path: 'subjects/:id/hero',
                builder: (_, state) => HeroCreatorScreen(
                  subjectId: state.pathParameters['id']!,
                  displayName: state.extra as String?,
                ),
              ),
              // The per-child daily bundle — avatar, today's words, mood, the
              // room's day, photo capture, and the moments gallery, one page.
              GoRoute(
                path: 'subjects/:id/day',
                builder: (_, state) => RouteTitle(
                  title: 'Today',
                  child: ChildDayScreen(
                    subjectId: state.pathParameters['id']!,
                  ),
                ),
              ),
              // The child's own WORLD (docs/VISION.md 2026-06-19) — their weekly
              // intention, their project, today's answer + hero, and their
              // growth, a bento that's all THEIRS.
              GoRoute(
                path: 'subjects/:id/world',
                builder: (_, state) => RouteTitle(
                  title: 'World',
                  child: ChildWorldScreen(
                    subjectId: state.pathParameters['id']!,
                  ),
                ),
              ),
              // The cumulative WORK trail — everything they've made, by day,
              // with the day-bar filmstrip (the "time-lapse").
              GoRoute(
                path: 'subjects/:id/trail',
                builder: (_, state) => RouteTitle(
                  title: 'Trail',
                  child: ChildTrailScreen(
                    subjectId: state.pathParameters['id']!,
                  ),
                ),
              ),
              GoRoute(
                path: 'activities',
                builder: (_, _) => const RouteTitle(
                  title: 'Activities',
                  child: ActivitiesListScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, _) => const RouteTitle(
                      title: 'New activity',
                      child: ActivityEditScreen(),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => RouteTitle(
                      title: 'Edit activity',
                      child: ActivityEditScreen(
                        activityId: state.pathParameters['id'],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const RouteTitle(
              title: 'Settings',
              child: SettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'program',
                builder: (_, _) => const RouteTitle(
                  title: 'Program',
                  child: ProgramSettingsScreen(),
                ),
              ),
              GoRoute(
                path: 'locations',
                builder: (_, _) => const RouteTitle(
                  title: 'Locations',
                  child: LocationsListScreen(),
                ),
              ),
              GoRoute(
                path: 'supplies',
                builder: (_, _) => const RouteTitle(
                  title: 'Supplies',
                  child: SuppliesListScreen(),
                ),
              ),
              GoRoute(
                path: 'missions',
                builder: (_, _) => const RouteTitle(
                  title: 'Missions',
                  child: MissionsListScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'board',
                    builder: (_, _) => const RouteTitle(
                      title: 'Today’s board',
                      child: MissionBoardScreen(),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'roles',
                builder: (_, _) => const RouteTitle(
                  title: 'Roles',
                  child: RolesScreen(),
                ),
              ),
              GoRoute(
                path: 'toolkit',
                builder: (_, _) => const RouteTitle(
                  title: 'Teacher Toolkit',
                  child: ToolkitScreen(),
                ),
                routes: [
                  // Per-tool detail as its own route — phone canvases push
                  // here from the catalog feed; deep-links land here too.
                  GoRoute(
                    path: ':slug',
                    builder: (_, state) => ToolkitToolScreen(
                      slug: state.pathParameters['slug']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'curricula/photo',
                builder: (_, _) => const RouteTitle(
                  title: 'Through My Eyes',
                  child: PhotoCurriculumScreen(),
                ),
              ),
              GoRoute(
                path: 'team',
                builder: (_, _) => const RouteTitle(
                  title: 'Team',
                  child: TeamScreen(),
                ),
                routes: [
                  // Invite flow (Wave 24, replaces InviteCreateSheet +
                  // InviteShareSheet bottom-sheets). Create → push-replace
                  // to share so back from share returns to Team, not to
                  // the create form.
                  GoRoute(
                    path: 'invite/new',
                    builder: (_, _) => const RouteTitle(
                      title: 'New invite',
                      child: InviteCreateScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'invite/:id',
                    builder: (_, state) {
                      final invite = state.extra;
                      if (invite is! Invite) {
                        return const _MissingInviteScreen();
                      }
                      return RouteTitle(
                        title: 'Invite',
                        child: InviteShareScreen(invite: invite),
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    // Dynamic title set in MemberDetailScreen.
                    builder: (_, state) => MemberDetailScreen(
                      memberId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Vehicles live at /vehicles (not /settings/vehicles).
          // Wave 95: driving is a daily operation, not a configuration —
          // burying it under settings made the route taxonomy lie about
          // the surface's role. Old /settings/vehicles* URLs still
          // resolve via a redirect (preserves any printed QR codes that
          // were generated before this rename).
          GoRoute(
            path: '/vehicles',
            builder: (_, _) => const RouteTitle(
              title: 'Vehicles',
              child: VehiclesListScreen(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const RouteTitle(
                  title: 'New vehicle',
                  child: VehicleEditScreen(),
                ),
              ),
              GoRoute(
                path: 'scan',
                builder: (_, _) => const RouteTitle(
                  title: 'Scan vehicle',
                  child: VehicleScanScreen(),
                ),
              ),
              GoRoute(
                path: ':id',
                // Dynamic title (vehicle name) set in VehicleDetailScreen.
                builder: (_, state) => VehicleDetailScreen(
                  vehicleId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => RouteTitle(
                      title: 'Edit vehicle',
                      child: VehicleEditScreen(
                        vehicleId: state.pathParameters['id'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'photo-checklist',
                    builder: (_, state) => RouteTitle(
                      title: 'Photo checklist',
                      child: VehiclePhotoShotsEditScreen(
                        vehicleId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'checkout',
                    builder: (_, state) => RouteTitle(
                      title: 'Check out vehicle',
                      child: VehicleInspectionScreen(
                        vehicleId: state.pathParameters['id']!,
                        kind: VehicleLogKind.checkout,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'checkin',
                    builder: (_, state) => RouteTitle(
                      title: 'Check in vehicle',
                      child: VehicleInspectionScreen(
                        vehicleId: state.pathParameters['id']!,
                        kind: VehicleLogKind.checkin,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Compatibility redirect: anything under /settings/vehicles
          // routes to the equivalent path under /vehicles. Keeps old
          // QR codes, bookmarks, and shared links working.
          GoRoute(
            path: '/settings/vehicles',
            redirect: (_, state) {
              final tail = state.uri.path.replaceFirst(
                '/settings/vehicles',
                '',
              );
              final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
              return '/vehicles$tail$query';
            },
          ),
          // Convenience aliases — the URL space a user would naturally
          // type or share. Each is a no-op redirect to the canonical
          // path. Keeps the route tree small while letting people
          // bookmark `/today` or share `/team` without remembering the
          // exact route.
          GoRoute(
            path: '/today',
            redirect: (_, _) => '/',
          ),
          GoRoute(
            path: '/home',
            redirect: (_, _) => '/',
          ),
          GoRoute(
            path: '/team',
            redirect: (_, _) => '/settings/team',
          ),
          GoRoute(
            path: '/program',
            redirect: (_, _) => '/settings/program',
          ),
          // Subjects-by-id alias: the staff path to a kid's profile lives
          // at /groups/:gid/students/:sid because the group context is
          // useful when you got there via a roster. But /subjects/:id
          // (engine-canonical) and /students/:id (vertical-label) are
          // both natural URLs to type or share. We look up the subject's
          // group at redirect time so the canonical URL still works.
          GoRoute(
            path: '/subjects/:id',
            redirect: (context, state) {
              final id = state.pathParameters['id']!;
              return '/students/$id';
            },
          ),
          GoRoute(
            path: '/students/:id',
            redirect: (context, state) async {
              final id = state.pathParameters['id']!;
              final container = ProviderScope.containerOf(
                context,
                listen: false,
              );
              // Wave 102 (Red Team #4): guardians have no subjects in
              // local Drift (their data comes via PostgREST fallback at
              // the family lens), so the Drift lookup below would always
              // return null and silently redirect to /. A director who
              // texts `/students/<id>` to a parent expects them to land
              // on the kid's profile. Detect the guardian path and route
              // to the family-side surface instead.
              final viewer = container.read(viewerProvider);
              if (viewer is GuardianViewer) {
                return '/children/$id';
              }
              try {
                final db = await container.read(appDatabaseProvider.future);
                final row = await (db.select(
                  db.subjects,
                )..where((s) => s.id.equals(id))).getSingleOrNull();
                final gid = row?.groupId;
                if (gid == null) return '/';
                return '/groups/$gid/students/$id';
              } on Object {
                // Any failure during the lookup → home, with the URL
                // change as the user's signal that something didn't
                // find what they wanted.
                return '/';
              }
            },
          ),
          GoRoute(
            path: '/login',
            builder: (_, _) => const RouteTitle(
              title: 'Sign in',
              child: LoginScreen(),
            ),
          ),
          // The omnibox search page — pushed when the user taps the
          // bottom bar (or hits Cmd/Ctrl-K). Lives inside the ShellRoute
          // so the chrome stack + drawer stay mounted across the push.
          //
          // **NoTransitionPage is kept (Wave-back-to-route 2026-06-20).**
          // The page owns its own autofocused field, so the keyboard
          // raises on mount regardless of the transition. But a slide-in
          // transition would animate the field in WHILE its autofocus
          // fires, which reads as a jittery "field flies in then the
          // keyboard pops" — no transition makes tap → page → keyboard
          // feel like one instant step. (The OLD reason — a transition
          // rotating focus AWAY from the shell-bar field and dismissing
          // the IME — no longer applies now that the field is on the
          // page, but no-transition is still the right feel.)
          GoRoute(
            path: '/search',
            pageBuilder: (_, _) => const NoTransitionPage<void>(
              child: OmniboxSearchScreen(),
            ),
          ),
          // The Brain Breaks deck — the home for the activity e-cards.
          GoRoute(
            path: '/breaks',
            builder: (_, _) => const BrainBreaksScreen(),
          ),
          // Heroes hub — the room-level roster bridge into the per-child
          // creator (docs/VISION.md 2026-06-19). Surfaced only when the
          // heroesEnabledProvider toggle is on; the route always resolves.
          GoRoute(
            path: '/heroes',
            builder: (_, _) => const HeroesHubScreen(),
          ),
          // The role deck — every child's role as a collectible card
          // (docs/VISION.md 2026-06-19). Opt-in with Heroes; the route always
          // resolves.
          GoRoute(
            path: '/deck',
            builder: (_, _) => const RoleDeckScreen(),
          ),
          // The role battle — a host-present card game with the roles
          // (docs/VISION.md 2026-06-19). Opt-in with Heroes.
          GoRoute(
            path: '/deck/play',
            builder: (_, _) => const RoleGameScreen(),
          ),
          // Routines — the kid-legible read of the day (docs/VISION.md
          // 2026-06-19). Surfaced only when routinesEnabledProvider is on.
          GoRoute(
            path: '/routines',
            builder: (_, state) =>
                RoutinesScreen(groupId: state.uri.queryParameters['group']),
          ),
          // The Daily — Question / Quote / Mission of the Day (docs/VISION.md
          // 2026-06-19). Surfaced only when dailyEnabledProvider is on.
          GoRoute(
            path: '/daily',
            builder: (_, state) =>
                DailyScreen(groupId: state.uri.queryParameters['group']),
          ),
          // The daily parent recap composer (docs/VISION.md 2026-06-19) —
          // staff assemble + send each family their child's day. Surfaced only
          // when recapEnabledProvider is on.
          GoRoute(
            path: '/recap',
            builder: (_, state) => RecapComposerScreen(
              groupId: state.uri.queryParameters['group'],
            ),
          ),
          // What to do instead — the room's calm reference (docs/VISION.md
          // 2026-06-19). Surfaced only when calmEnabledProvider is on.
          GoRoute(path: '/calm', builder: (_, _) => const CalmScreen()),
          // The Spellbook — a magic-framed home gathering today + this week +
          // the story (docs/VISION.md 2026-06-19). Only when the toggle is on.
          GoRoute(
            path: '/spellbook',
            builder: (_, _) => const SpellbookScreen(),
          ),
          // This Week — the live curriculum hub (the world the room is in
          // now + cast / worksheets / activities). docs/WORLD.md.
          GoRoute(
            path: '/this-week',
            builder: (_, _) => const RouteTitle(
              title: 'This week’s world',
              child: ThisWeekScreen(),
            ),
          ),
          // Project a world fullscreen to the room (device → projector).
          // Goes immersive via castImmersiveProvider.
          GoRoute(
            path: '/present-world/:id',
            builder: (_, state) => WorldPresentScreen(
              worldId: state.pathParameters['id']!,
            ),
          ),
          // Project a cohort's LIVE schedule block to the room — the slide cast
          // to the TV (docs/VISION.md 2026-06-19). Auto-advances as the day's
          // live block changes. Immersive via castImmersiveProvider.
          GoRoute(
            path: '/present-room/:groupId',
            builder: (_, state) => BlockPresentScreen(
              groupId: state.pathParameters['groupId']!,
            ),
          ),
          // The GENERIC present surface (docs/VISION.md 2026-06-20: "everything
          // could be turned into slides"). Any feature builds a List<PresentSlide>
          // and throws it here via presentSlides(); the deck rides go_router
          // `extra`. Immersive via castImmersiveProvider.
          GoRoute(
            path: '/present-deck',
            builder: (_, state) {
              final args = state.extra;
              return args is PresentDeckArgs
                  ? SlidePresentScreen(title: args.title, slides: args.slides)
                  : const SlidePresentScreen(
                      title: '',
                      slides: <PresentSlide>[],
                    );
            },
          ),
          // "Play today" — the whole day on rails, one immersive run of show
          // assembled from this week's world (docs/VISION.md "day, on rails").
          // With the deck-overview toggle ON, DayRunScreen renders the tappable
          // grid and pushes the immersive presenter at the chosen beat via the
          // nested `present` route below.
          GoRoute(
            path: '/play-today',
            builder: (_, _) => const DayRunScreen(),
            routes: [
              // The immersive presenter, fed by a DeckPresentArgs over `extra`.
              // EdgeScaffold (NOT a bare Scaffold) so the immersive surface
              // gets the same chrome-clearing wrapper the base screen uses; a
              // missing `extra` (cold deep-link) falls back to the overview.
              GoRoute(
                path: 'present',
                builder: (_, state) {
                  final args = state.extra;
                  if (args is! DeckPresentArgs) {
                    return const DayRunScreen();
                  }
                  return EdgeScaffold(
                    body: BeatPresenter(
                      beats: args.beats,
                      accent: args.accent,
                      emoji: args.emoji,
                      initialBeat: args.initialBeat,
                      onBeatChanged: args.onBeatChanged,
                    ),
                  );
                },
              ),
            ],
          ),
          // The teleprompter for teaching — ANY activity (typed on /lens, or
          // generic) presented through its play → name → bridge → question
          // arc as a castable prompt (docs/VISION.md "like a prompt").
          GoRoute(
            path: '/arc',
            builder: (_, state) {
              final extra = state.extra;
              return ActivityArcScreen(
                activity: extra is String ? extra : '',
              );
            },
          ),
          // One cast that walks the WHOLE summer — the journey, world by world
          // (docs/VISION.md "one cast that walks the whole experience"). With
          // the deck-overview toggle ON, JourneyTourScreen renders the tappable
          // grid and pushes the immersive presenter at the chosen world-beat via
          // the nested `present` route below.
          GoRoute(
            path: '/journey',
            builder: (_, _) => const JourneyTourScreen(),
            routes: [
              // The immersive presenter, fed by a DeckPresentArgs over `extra`.
              // EdgeScaffold (NOT a bare Scaffold) — same wrapper the base
              // screen uses; a missing `extra` falls back to the overview.
              GoRoute(
                path: 'present',
                builder: (_, state) {
                  final args = state.extra;
                  if (args is! DeckPresentArgs) {
                    return const JourneyTourScreen();
                  }
                  return EdgeScaffold(
                    body: BeatPresenter(
                      beats: args.beats,
                      accent: args.accent,
                      emoji: args.emoji,
                      initialBeat: args.initialBeat,
                      onBeatChanged: args.onBeatChanged,
                    ),
                  );
                },
              ),
            ],
          ),
          // A child's GROWTH ARC — their story so far (words lived, worlds
          // collected, emerging title), cast on the present spine. The
          // showcase as an in-app compilation (docs/VISION.md).
          GoRoute(
            path: '/growth/:subjectId',
            builder: (_, state) => GrowthArcScreen(
              subjectId: state.pathParameters['subjectId']!,
            ),
          ),
          // The SEASON HUB — the whole 10-week program on one screen (where we
          // are, the two layers, today, the journey, each child's arc). The
          // in-app counterpart to docs/PROGRAM.md.
          GoRoute(
            path: '/program',
            builder: (_, _) => const RouteTitle(
              title: 'The program',
              child: ProgramHubScreen(),
            ),
          ),
          // A child's Book — their 10-week journey grouped by world.
          GoRoute(
            path: '/book/:subjectId',
            builder: (_, state) => RouteTitle(
              title: 'Book',
              child: BookScreen(subjectId: state.pathParameters['subjectId']!),
            ),
          ),
          // The staff growth ladder — Shadow → Conductor, self-marked.
          GoRoute(
            path: '/staff',
            builder: (_, _) => const RouteTitle(
              title: 'The staff ladder',
              child: StaffLadderScreen(),
            ),
          ),
          // Ready to run — the pre-9:00 readiness check for tomorrow.
          GoRoute(
            path: '/ready',
            builder: (_, _) => const RouteTitle(
              title: 'Ready to run',
              child: LaunchScreen(),
            ),
          ),
          // The activity forge — verb × noun × constraint × time generator.
          GoRoute(
            path: '/forge',
            builder: (_, _) => const RouteTitle(
              title: 'Make an activity',
              child: ActivityForgeScreen(),
            ),
          ),
          // Any activity, the Different World way — the lens over your own.
          GoRoute(
            path: '/lens',
            builder: (_, _) => const RouteTitle(
              title: 'Any activity',
              child: ActivityLensScreen(),
            ),
          ),
          // The printable toolkit — generate the binder pages offline.
          GoRoute(
            path: '/print',
            builder: (_, _) => const RouteTitle(
              title: 'Printable toolkit',
              child: PrintToolkitScreen(),
            ),
          ),
          // The staff runbook — the day moment-by-moment for the grown-ups.
          GoRoute(
            path: '/runbook',
            builder: (_, _) => const RouteTitle(
              title: 'Runbook',
              child: RunbookScreen(),
            ),
          ),
          // Verb spine — each verb as a kid job (+ script), a 3-level
          // mission, and a 3-level staff skill. One vocabulary, three lives.
          GoRoute(
            path: '/verb-jobs',
            builder: (_, _) => const RouteTitle(
              title: 'Jobs & missions',
              child: VerbJobsScreen(),
            ),
          ),
          // Big Thinking — play → name → bridge → question games.
          GoRoute(
            path: '/thinking',
            builder: (_, _) => const RouteTitle(
              title: 'Big Thinking',
              child: ThinkingScreen(),
            ),
          ),
          // The room's Wall for this week's world (anonymous notes).
          GoRoute(
            path: '/wall',
            builder: (_, _) => const RouteTitle(
              title: 'The Wall',
              child: WallScreen(),
            ),
          ),
          // Time capsules — sealed until their day.
          GoRoute(
            path: '/time-capsules',
            builder: (_, _) => const RouteTitle(
              title: 'Time capsules',
              child: TimeCapsuleScreen(),
            ),
          ),
          // Spells — fullscreen timer commands, each a word in another
          // language (docs/ACTION_WORDS.md). The brief's one loud moment.
          GoRoute(
            path: '/spells',
            builder: (_, _) =>
                const RouteTitle(title: 'Spells', child: SpellsScreen()),
          ),
          // The room Story — the whole class's moments woven over time.
          GoRoute(
            path: '/story',
            builder: (_, _) =>
                const RouteTitle(title: 'Room story', child: RoomStoryScreen()),
          ),
          // A child's Story — every captured moment woven into one
          // continuous, date-grouped timeline (the memory layer).
          GoRoute(
            path: '/story/:subjectId',
            builder: (_, state) => RouteTitle(
              title: 'Story',
              child: KidStoryScreen(
                subjectId: state.pathParameters['subjectId']!,
              ),
            ),
          ),
          // Play the story — the showcase presentation of the timeline
          // (docs/VISION.md 2026-06-19, "the drawing becomes a film").
          GoRoute(
            path: '/story/:subjectId/play',
            builder: (_, state) => RouteTitle(
              title: 'Play the story',
              child: StoryShowcaseScreen(
                subjectId: state.pathParameters['subjectId']!,
              ),
            ),
          ),
          // The Thinking Tools library (docs/THINKING_TOOLS.md) — one shelf
          // over the runnable activities + the editorial reference cards.
          GoRoute(
            path: '/tools',
            builder: (_, _) =>
                const RouteTitle(title: 'Tools', child: ToolsScreen()),
          ),
          // Reflect — the stopwatch-then-reflect ritual: time the real work,
          // then a required how-did-it-go; saved reflections stack into a
          // visible growth strip (docs/VISION.md, 2026-06-14).
          GoRoute(
            path: '/reflect',
            builder: (_, _) => const RouteTitle(
              title: 'Reflect',
              child: ReflectionSessionScreen(),
            ),
          ),
          // Speak — paste a prompt / quote / block, hear it read with big
          // kinetic karaoke subtitles (ElevenLabs via the tts-subtitles
          // Edge Function). docs/FEATURE_CHECKLISTS.md.
          GoRoute(
            path: '/speak',
            builder: (_, _) =>
                const RouteTitle(title: 'Speak', child: SpeakScreen()),
          ),
          // Join ANY live session program-wide (docs/LIVE_SESSIONS.md "One
          // place to join"): the game is resolved from the link
          // (/join?code=RJ4K&game=charades) via gameById, so the joiner never
          // has to pick the game first. The Today live banner pushes here.
          GoRoute(
            path: '/join',
            builder: (_, state) {
              final code = (state.uri.queryParameters['code'] ?? '')
                  .trim()
                  .toUpperCase();
              final def = gameById(state.uri.queryParameters['game'] ?? '');
              if (def == null || code.isEmpty) {
                return const RouteTitle(
                  title: 'Join',
                  child: JoinUnavailableScreen(),
                );
              }
              return RouteTitle(
                title: 'Join',
                child: LiveGameScreen(
                  def: def,
                  autoJoin: (code: code, role: SessionRole.control),
                ),
              );
            },
          ),
          // Live present/control for This-or-That (docs/LIVE_SESSIONS.md):
          // present on a big screen, control from a phone over Realtime.
          GoRoute(
            path: '/live/this-or-that',
            builder: (_, _) => const LiveGameScreen(def: ThisOrThatGame()),
          ),
          GoRoute(
            path: '/live/riddles',
            builder: (_, _) => const LiveGameScreen(def: RiddlesGame()),
          ),
          GoRoute(
            path: '/live/grid-reveal',
            builder: (_, _) => const LiveGameScreen(def: GridRevealGame()),
          ),
          GoRoute(
            path: '/live/fact-or-fib',
            builder: (_, _) => const LiveGameScreen(def: FactOrFibGame()),
          ),
          // The classroom remote (docs/VISION.md #18). /present = the hub;
          // /present/<id> = single-device, /live/<id> = two-device.
          GoRoute(
            path: '/present',
            builder: (_, _) => const PresentHubScreen(),
          ),
          // The app remote / cast model (docs/LIVE_SESSIONS.md "the cast
          // model"): one device is a clean Receiver; this phone is the Caster
          // (pick + drive + switch what's on the screen).
          GoRoute(
            path: '/cast',
            builder: (_, state) => CastScreen(
              // ?role=screen → open straight into room-screen (receiver) mode
              // on the program channel (the "make this the screen" setup +
              // launch auto-resume use it).
              presentAsScreen: state.uri.queryParameters['role'] == 'screen',
            ),
          ),
          // The Live Board — the phone as a classroom instrument
          // (docs/LIVE_BOARD.md). Casts to the room screens via the same
          // spine as /cast; room screens join through the cast receiver.
          GoRoute(
            path: '/live-board',
            builder: (_, _) => const LiveBoardScreen(),
          ),
          GoRoute(
            path: '/present/poll',
            builder: (_, _) => const GameRunner(def: PollGame()),
          ),
          GoRoute(
            path: '/live/poll',
            builder: (_, _) => const LiveGameScreen(def: PollGame()),
          ),
          GoRoute(
            path: '/present/cues',
            builder: (_, _) => const GameRunner(def: CuesGame()),
          ),
          GoRoute(
            path: '/live/cues',
            builder: (_, _) => const LiveGameScreen(def: CuesGame()),
          ),
          GoRoute(
            path: '/present/picker',
            builder: (_, _) => const PickerScreen(live: false),
          ),
          GoRoute(
            path: '/live/picker',
            builder: (_, _) => const PickerScreen(live: true),
          ),
          GoRoute(
            path: '/present/now-next',
            builder: (_, _) => const NowNextScreen(live: false),
          ),
          GoRoute(
            path: '/live/now-next',
            builder: (_, _) => const NowNextScreen(live: true),
          ),
          // Name It — picture-card vocabulary game over the bundled deck
          // (docs/CARD_GAMES.md). Deck-seeded like Now & Next.
          GoRoute(
            path: '/present/name-it',
            builder: (_, _) => const NameItScreen(live: false),
          ),
          GoRoute(
            path: '/live/name-it',
            builder: (_, _) => const NameItScreen(live: true),
          ),
          // Odd One Out — three from a category + one stranger; tap Reveal and
          // the odd card rings itself (docs/CARD_GAMES.md). Deck-seeded.
          GoRoute(
            path: '/present/odd-one-out',
            builder: (_, _) => const OddOneOutScreen(live: false),
          ),
          GoRoute(
            path: '/live/odd-one-out',
            builder: (_, _) => const OddOneOutScreen(live: true),
          ),
          // What's Missing — study the set, hide one, name what vanished
          // (docs/CARD_GAMES.md). Three beats per round; deck-seeded.
          GoRoute(
            path: '/present/whats-missing',
            builder: (_, _) => const WhatsMissingScreen(live: false),
          ),
          GoRoute(
            path: '/live/whats-missing',
            builder: (_, _) => const WhatsMissingScreen(live: true),
          ),
          // Memory / Match — concentration over the picture deck; tap two, a
          // match locks (docs/CARD_GAMES.md). Deck-seeded; custom remote.
          GoRoute(
            path: '/present/memory-match',
            builder: (_, _) => const MemoryMatchScreen(live: false),
          ),
          GoRoute(
            path: '/live/memory-match',
            builder: (_, _) => const MemoryMatchScreen(live: true),
          ),
          // The Poster tool — tile one image across N×N letter pages to
          // print + tape into a big poster.
          GoRoute(
            path: '/poster',
            // `extra` may carry a seed image (e.g. a Pattern rasterized into a
            // poster — the Artifact contract). Null = the normal chooser.
            builder: (_, state) =>
                PosterScreen(seedImage: state.extra as Uint8List?),
          ),
          // Charades — the showcase: room sees the category, the actor's
          // phone shows the secret word, the teacher's phone marks Got it.
          GoRoute(
            path: '/live/charades',
            builder: (_, _) => const LiveGameScreen(def: CharadesGame()),
          ),
          // Anonymous brainstorm / agenda board (docs/VISION.md #5): phones
          // post ideas to a projected wall, no names, over Realtime.
          GoRoute(
            path: '/board',
            builder: (_, _) => const BoardScreen(),
          ),
          // Do a mission (docs/MISSIONS.md slice 2) — the Mission rides in
          // `extra`; a bare deep-link bounces to the catalog.
          GoRoute(
            path: '/missions/do',
            redirect: (_, state) =>
                state.extra is Mission ? null : '/settings/missions',
            builder: (_, state) =>
                MissionDoScreen(mission: state.extra! as Mission),
          ),
          // The Math inverse activity — a conducted, kid-mode experience
          // (docs/ACTIVITY_RUNTIME.md, Slice 2). Under the ShellRoute so
          // AppShell strips its chrome while kid mode is locked. `?target=N`
          // seeds the answer; defaults to 12.
          GoRoute(
            path: '/activity/math',
            builder: (_, state) => MathRunnerScreen(
              target:
                  int.tryParse(state.uri.queryParameters['target'] ?? '') ?? 12,
            ),
          ),
          // Math GAME — one question at a time, mixed mechanics.
          GoRoute(
            path: '/activity/math-game',
            builder: (_, _) => const GameRunner(def: MathQuizGame()),
          ),
          GoRoute(
            path: '/live/math-game',
            builder: (_, _) => const LiveGameScreen(def: MathQuizGame()),
          ),
          // The Photography activity — opens straight to a full-screen
          // camera, kid-mode locked (docs/ACTIVITY_RUNTIME.md). `?prompt=`
          // sets the overlay instruction.
          GoRoute(
            path: '/activity/photo',
            builder: (_, state) => PhotographyRunnerScreen(
              prompt:
                  state.uri.queryParameters['prompt'] ?? 'Capture what you see',
            ),
          ),
          // This or That — a kid-mode binary-choice game, content from the
          // content bank (docs/ACTIVITY_RUNTIME.md + CONTENT_BANK.md).
          GoRoute(
            path: '/activity/this-or-that',
            builder: (_, _) => const GameRunner(def: ThisOrThatGame()),
          ),
          // "Starts with" word game — content from the content bank.
          GoRoute(
            path: '/activity/starts-with',
            builder: (_, _) => const GameRunner(def: LetterWordsGame()),
          ),
          GoRoute(
            path: '/live/starts-with',
            builder: (_, _) => const LiveGameScreen(def: LetterWordsGame()),
          ),
          // "As If" acting game — perform a line in an emotion/character.
          GoRoute(
            path: '/activity/as-if',
            builder: (_, _) => const GameRunner(def: AsIfGame()),
          ),
          GoRoute(
            path: '/live/as-if',
            builder: (_, _) => const LiveGameScreen(def: AsIfGame()),
          ),
          // Role Cards — animal & nature roles as SMART daily practices
          // (docs/ROLES_SMART_PRACTICE.md). Browse the catalog; each card is
          // 3 habits + 3 artifacts + a trait.
          GoRoute(
            path: '/activity/roles',
            // `extra` carries the child when opened via "Practice a role" from
            // their world, so each artifact tool captures straight to them;
            // null when browsing the catalog.
            builder: (_, state) =>
                RoleCardsScreen(subject: state.extra as RoleSubject?),
          ),
          // Riddles — host-run, answer-first; the room guesses, you Reveal.
          GoRoute(
            path: '/activity/riddles',
            builder: (_, _) => const GameRunner(def: RiddlesGame()),
          ),
          GoRoute(
            path: '/activity/grid-reveal',
            builder: (_, _) => const GameRunner(def: GridRevealGame()),
          ),
          // Mindful Minute — a calm breathing break (the regulation gap).
          GoRoute(
            path: '/activity/breathe',
            builder: (_, _) => const BreatheScreen(),
          ),
          // Do It — a real-world action to actually perform; "We did it!"
          // leaves an accumulating record (docs/VISION.md 2026-06-18). Unlike
          // the ephemeral games, doing it persists into the Book.
          GoRoute(
            path: '/activity/do-it',
            builder: (_, state) =>
                DoItScreen(groupId: state.uri.queryParameters['group']),
          ),
          // Fill in the blank (ad libs) — host-typed, read aloud at the
          // reveal (docs/VISION.md 2026-06-19).
          GoRoute(
            path: '/activity/fill-blank',
            builder: (_, _) => const FillBlankScreen(),
          ),
          // Letters — the room writes to each other; the app pairs everyone so
          // each writes one + gets one (docs/VISION.md 2026-06-19).
          GoRoute(
            path: '/activity/letters',
            builder: (_, state) =>
                LettersScreen(groupId: state.uri.queryParameters['group']),
          ),
          // Penny for a Thought — share a thought, drop a penny, count the pile
          // (counting math, docs/VISION.md 2026-06-19).
          GoRoute(
            path: '/activity/penny',
            builder: (_, _) => const PennyScreen(),
          ),
          // Potions — a potion-of-the-moment recipe the room makes for real
          // (garden + counting + magic, docs/VISION.md 2026-06-19).
          GoRoute(
            path: '/activity/potions',
            builder: (_, _) => const PotionsScreen(),
          ),
          // Fact or Fib — host-run; the room votes true/false, you Reveal.
          GoRoute(
            path: '/activity/fact-or-fib',
            builder: (_, _) => const GameRunner(def: FactOrFibGame()),
          ),
          // Story Starters — host-run; the room builds a story aloud.
          GoRoute(
            path: '/activity/story',
            builder: (_, _) => const GameRunner(def: StoryStartersGame()),
          ),
          GoRoute(
            path: '/live/story',
            builder: (_, _) => const LiveGameScreen(def: StoryStartersGame()),
          ),
          // Rhyme Time — host-run; the room shouts rhymes, you tally.
          GoRoute(
            path: '/activity/rhyme-time',
            builder: (_, _) => const GameRunner(def: RhymeTimeGame()),
          ),
          GoRoute(
            path: '/live/rhyme-time',
            builder: (_, _) => const LiveGameScreen(def: RhymeTimeGame()),
          ),
          // Make a Pattern — draw/build a tile in real life, snap it, watch
          // it repeat (kaleidoscope mirroring → symmetry from any tile).
          GoRoute(
            path: '/activity/pattern',
            builder: (_, _) => const PatternMakerScreen(),
          ),
          // Group Discussions — host-present talk by topic + age band, from
          // the kid-safe discussion library (docs/VISION.md dream #6).
          GoRoute(
            path: '/activity/discussions',
            builder: (_, _) => const GroupDiscussionScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Fallback when `/settings/team/invite/:id` is deep-linked without
/// the `extra` payload — happens on cold launch + paste-URL. We can't
/// reconstitute the Invite without a fetch, so degrade to a clear
/// error rather than crash. Future: an `inviteByIdProvider` would
/// let us fetch + render properly.
class _MissingInviteScreen extends StatelessWidget {
  const _MissingInviteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Open this invite from the Team screen — direct links '
              'are not supported yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback when `/exports/:id/send` is opened without the `extra`
/// payload — happens if a deep link is pasted cold. Future: an
/// `exportByIdProvider` would let us fetch + render properly.
class _MissingExportScreen extends StatelessWidget {
  const _MissingExportScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Open this export from the report screen — direct links '
              'are not supported yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback when `/subjects/:id/health` is opened without the
/// `extra` payload — same pattern as the other "missing extra"
/// fallbacks. Future: a `subjectByIdProvider` lookup would let us
/// fetch + render.
class _MissingSubjectScreen extends StatelessWidget {
  const _MissingSubjectScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Open the child's profile from the roster — direct "
              'links are not supported yet.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wave 111: friendly 404 surface. Reached via GoRouter's
/// `errorBuilder` whenever a path doesn't match any registered
/// route (typo'd deep link, stale bookmark, an old URL from before
/// a refactor). Shows the typo'd URL back to the user so they can
/// spot a fixable mistake, and offers a single CTA back to Today.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.travel_explore_outlined,
                    size: 72,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "We can't find that page.",
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The URL might be from an older version of the '
                    "app, or there's a typo. Check the address and "
                    'try again, or head back home.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      uri,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Back to home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouterAuthRefresh extends ChangeNotifier {
  _RouterAuthRefresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Family lens wins — if the signed-in user has a guardian row,
    // we render the family Today and skip the staff-side state
    // machine entirely. The viewerProvider resolves to GuardianViewer
    // automatically in that case.
    final viewer = ref.watch(viewerProvider);
    if (viewer is GuardianViewer) {
      return const FamilyTodayScreen(key: ValueKey('family'));
    }

    final memberAsync = ref.watch(currentMemberProvider);

    final child = memberAsync.when(
      // The first sync after sign-in: Member row hasn't arrived yet.
      // Show a spinner instead of flashing the onboarding screen.
      loading: () => const _SyncingScaffold(key: ValueKey('syncing')),
      error: (err, _) => _ErrorScaffold(
        key: const ValueKey('error'),
        error: err,
      ),
      data: (member) {
        if (member == null) {
          return const _SyncingScaffold(key: ValueKey('syncing'));
        }
        if (member.spaceId == null) {
          return const JoinOrCreateScreen(key: ValueKey('join'));
        }
        return const _SignedInHome(key: ValueKey('home'));
      },
    );

    // Fade between the three top-level states (syncing → join → home)
    // so the swap is smooth when the member row arrives mid-boot.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }
}

/// Home is just Today — search is now inline (the chrome transforms
/// into a search input on Today itself), so the PageView the omnibox
/// used to occupy is gone. It's a stateful host because Today is where
/// pending deep links get consumed: invite codes that arrive while the
/// user already has a space (refuse + snackbar), and vehicle QR links
/// (push to the inspection route).
///
/// Two consumption paths, both required:
/// - **Cold launch** (the QR case): `app_links` stashes the link during
///   boot, before this post-sync home mounts, so a one-shot drain in
///   `initState` handles a value that's already pending by mount time.
/// - **Warm** (link arrives while we're already on Today): the
///   `ref.listen`s in `build` catch the change.
/// A `ref.listen` ALONE is not enough — it only fires on change, so it
/// silently misses the cold-launch value. See the CLAUDE.md gotcha
/// "Flutter 3.24+ deep-linking-by-default" + its cold-launch sibling.
class _SignedInHome extends ConsumerStatefulWidget {
  const _SignedInHome({super.key});

  @override
  ConsumerState<_SignedInHome> createState() => _SignedInHomeState();
}

class _SignedInHomeState extends ConsumerState<_SignedInHome> {
  @override
  void initState() {
    super.initState();
    // Drain a link that was already pending before we mounted (cold
    // launch). Navigating during initState is illegal, so defer to
    // after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vehicle = ref.read(pendingVehicleDeepLinkProvider);
      if (vehicle != null) {
        _handleVehicleLink(vehicle);
        return;
      }
      final invite = ref.read(pendingInviteCodeProvider);
      if (invite != null && invite.isNotEmpty) _handleInviteCode();
    });
  }

  // A signed-in user with a space can't redeem an invite — refuse
  // cleanly and clear the pending code so they aren't bounced into some
  // other state. Switching programs is a sign-out-and-back-in workflow
  // for now.
  void _handleInviteCode() {
    ref.read(pendingInviteCodeProvider.notifier).clear();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          "You're already in a program. Sign out first to join a "
          'different one.',
        ),
      ),
    );
  }

  // Vehicle deep links — driver scans the QR on the dashboard, OS opens
  // the app, we land here, push to the inspection route. `canDrive` is
  // enforced by the inspection screen itself; we don't gate here so a
  // driver who's been temporarily off-duty still gets a clear "you
  // can't submit" inside the form (rather than a silent no-op).
  void _handleVehicleLink(VehicleDeepLink link) {
    ref.read(pendingVehicleDeepLinkProvider.notifier).clear();
    // Defer the push a microtask so we never push while a build/settle
    // is in flight — same pattern AppShell uses for routeChromeProvider.
    unawaited(
      Future<void>.microtask(() async {
        if (mounted) await context.push(link.routePath);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingInviteCodeProvider, (prev, next) {
      if (next == null || next.isEmpty) return;
      _handleInviteCode();
    });
    // Two distinct listener registrations; a `ref..listen()..listen()`
    // cascade would read worse than two plain statements.
    // ignore: cascade_invocations
    ref.listen<VehicleDeepLink?>(pendingVehicleDeepLinkProvider, (prev, next) {
      if (next == null) return;
      _handleVehicleLink(next);
    });

    // Slice 4 (docs/COCKPIT.md): the home surface is Today by default, the
    // clock-driven cockpit when the director opts in, or the bento dashboard
    // when THAT's opted in. Today is never lost — it's reachable at /today.
    // Precedence: cockpit > bento > Today (cockpit is the established
    // promotion path; bento is the grid-navigation experiment).
    final cockpitAsHome = ref.watch(cockpitAsHomeProvider).value ?? false;
    final bentoHome =
        (ref.watch(bentoEverywhereProvider).value ?? false) ||
        (ref.watch(bentoHomeProvider).value ?? false);
    if (cockpitAsHome) {
      return const NowCockpitScreen(key: ValueKey('cockpit-home'));
    }
    if (bentoHome) {
      return const TodayBentoScreen(key: ValueKey('bento-home'));
    }
    return const TodayScreen(key: ValueKey('today-home'));
  }
}

class _SyncingScaffold extends StatelessWidget {
  const _SyncingScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Syncing your profile…'),
          ],
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wave 101 (Red Team #7): the raw `error.toString()` used to be
    // rendered on-screen, which could expose internal Dart class names,
    // SQLite file paths, or Supabase URLs to a non-technical end user
    // (and to anyone glancing at a school-shared device). Show a
    // generic message; log the detail in debug builds only.
    if (kDebugMode) debugPrint('Profile load error: $error');
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Something went wrong loading your profile.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Try restarting the app. If this keeps happening, '
                'sign out and back in.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
