import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart'
    show Entry, Export, Invite, Mission, Subject;
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/activity_runtime/as_if_screen.dart';
import 'package:differentworld/features/activity_runtime/brain_breaks_screen.dart';
import 'package:differentworld/features/activity_runtime/breathe_screen.dart';
import 'package:differentworld/features/activity_runtime/discussions_screen.dart';
import 'package:differentworld/features/activity_runtime/letter_words_screen.dart';
import 'package:differentworld/features/activity_runtime/math_game_screen.dart';
import 'package:differentworld/features/activity_runtime/math_runner_screen.dart';
import 'package:differentworld/features/activity_runtime/pattern_maker_screen.dart';
import 'package:differentworld/features/activity_runtime/photography_runner_screen.dart';
import 'package:differentworld/features/activity_runtime/rhyme_time_screen.dart';
import 'package:differentworld/features/activity_runtime/role_cards_screen.dart';
import 'package:differentworld/features/activity_runtime/story_starters_screen.dart';
import 'package:differentworld/features/attendance/attendance_screen.dart';
import 'package:differentworld/features/attendance/morning_checklist_screen.dart';
import 'package:differentworld/features/auth/login_screen.dart';
import 'package:differentworld/features/captures/capture_inbox_screen.dart';
import 'package:differentworld/features/captures/capture_screen.dart';
import 'package:differentworld/features/curricula/photo_curriculum_screen.dart';
import 'package:differentworld/features/entries/observation_form_screen.dart';
import 'package:differentworld/features/entries/observations_index_screen.dart';
import 'package:differentworld/features/entries/observations_screen.dart';
import 'package:differentworld/features/exports/progress_report_screen.dart';
import 'package:differentworld/features/exports/send_export_screen.dart';
import 'package:differentworld/features/family/family_messages_screen.dart';
import 'package:differentworld/features/family/family_subject_detail_screen.dart';
import 'package:differentworld/features/family/family_today_screen.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/cues_game.dart';
import 'package:differentworld/features/games/games/fact_or_fib_game.dart';
import 'package:differentworld/features/games/games/poll_game.dart';
import 'package:differentworld/features/games/games/riddles_game.dart';
import 'package:differentworld/features/games/games/this_or_that_game.dart';
import 'package:differentworld/features/groups/group_detail_screen.dart';
import 'package:differentworld/features/groups/group_edit_screen.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:differentworld/features/invites/invite_create_screen.dart';
import 'package:differentworld/features/invites/invite_share_screen.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/live_session/board_screen.dart';
import 'package:differentworld/features/live_session/charades_live_screen.dart';
import 'package:differentworld/features/live_session/live_game_screen.dart';
import 'package:differentworld/features/messages/message_thread_screen.dart';
import 'package:differentworld/features/missions/mission_do_screen.dart';
import 'package:differentworld/features/missions/missions_list_screen.dart';
import 'package:differentworld/features/omnibox/omnibox_search_screen.dart';
import 'package:differentworld/features/onboarding/join_or_create_screen.dart';
import 'package:differentworld/features/review/weekly_review_screen.dart';
import 'package:differentworld/features/review/yearly_review_screen.dart';
import 'package:differentworld/features/schedule/activities_list_screen.dart';
import 'package:differentworld/features/schedule/activity_edit_screen.dart';
import 'package:differentworld/features/schedule/block_edit_screen.dart';
import 'package:differentworld/features/schedule/locations_list_screen.dart';
import 'package:differentworld/features/schedule/schedule_screen.dart';
import 'package:differentworld/features/schedule/trip_detail_screen.dart';
import 'package:differentworld/features/schedule/weekly_template_screen.dart';
import 'package:differentworld/features/settings/member_detail_screen.dart';
import 'package:differentworld/features/settings/program_settings_screen.dart';
import 'package:differentworld/features/settings/roles_screen.dart';
import 'package:differentworld/features/settings/settings_screen.dart';
import 'package:differentworld/features/settings/team_screen.dart';
import 'package:differentworld/features/subjects/health_profile_screen.dart';
import 'package:differentworld/features/subjects/subject_detail_screen.dart';
import 'package:differentworld/features/subjects/subject_edit_screen.dart';
import 'package:differentworld/features/supplies/supplies_list_screen.dart';
import 'package:differentworld/features/surveys/survey_list_screen.dart';
import 'package:differentworld/features/surveys/survey_table_screen.dart';
import 'package:differentworld/features/surveys/survey_take_screen.dart';
import 'package:differentworld/features/tasks/task_screen.dart';
import 'package:differentworld/features/tasks/tasks_screen.dart';
import 'package:differentworld/features/today/today_screen.dart';
import 'package:differentworld/features/toolkit/toolkit_screen.dart';
import 'package:differentworld/features/toolkit/toolkit_tool_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_deep_link.dart';
import 'package:differentworld/features/vehicles/vehicle_detail_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_edit_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_inspection_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_scan_screen.dart';
import 'package:differentworld/features/vehicles/vehicles_list_screen.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart'
    show VehicleLogKind;
import 'package:differentworld/shared/widgets/app_shell.dart';
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
          // The omnibox search screen — pushed when the user taps the
          // bottom composer. Lives inside the ShellRoute so the persistent
          // omnibox bar + chrome stay mounted across the push. See Wave 17.
          //
          // **NoTransitionPage is load-bearing.** A standard MaterialPage
          // slide-in transition rotates focus scope mid-flight, which
          // dismisses the keyboard the user just raised by tapping the
          // bar. With no transition, focus stays put and the keyboard
          // stays up — tap-to-search opens the route AND the keyboard
          // in one step. (Wave 20.)
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
            path: '/live/fact-or-fib',
            builder: (_, _) => const LiveGameScreen(def: FactOrFibGame()),
          ),
          // Non-game presentables (docs/VISION.md #18 — the classroom remote):
          // same engine, /present = single-device, /live = two-device.
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
          // Charades — the showcase: room sees the category, the actor's
          // phone shows the secret word, the teacher's phone marks Got it.
          GoRoute(
            path: '/live/charades',
            builder: (_, _) => const CharadesLiveScreen(),
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
            builder: (_, _) => const MathGameScreen(),
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
            builder: (_, _) => const LetterWordsScreen(),
          ),
          // "As If" acting game — perform a line in an emotion/character.
          GoRoute(
            path: '/activity/as-if',
            builder: (_, _) => const AsIfScreen(),
          ),
          // Role Cards — animal & nature roles as SMART daily practices
          // (docs/ROLES_SMART_PRACTICE.md). Browse the catalog; each card is
          // 3 habits + 3 artifacts + a trait.
          GoRoute(
            path: '/activity/roles',
            builder: (_, _) => const RoleCardsScreen(),
          ),
          // Riddles — host-run, answer-first; the room guesses, you Reveal.
          GoRoute(
            path: '/activity/riddles',
            builder: (_, _) => const GameRunner(def: RiddlesGame()),
          ),
          // Mindful Minute — a calm breathing break (the regulation gap).
          GoRoute(
            path: '/activity/breathe',
            builder: (_, _) => const BreatheScreen(),
          ),
          // Fact or Fib — host-run; the room votes true/false, you Reveal.
          GoRoute(
            path: '/activity/fact-or-fib',
            builder: (_, _) => const GameRunner(def: FactOrFibGame()),
          ),
          // Story Starters — host-run; the room builds a story aloud.
          GoRoute(
            path: '/activity/story',
            builder: (_, _) => const StoryStartersScreen(),
          ),
          // Rhyme Time — host-run; the room shouts rhymes, you tally.
          GoRoute(
            path: '/activity/rhyme-time',
            builder: (_, _) => const RhymeTimeScreen(),
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

    return const TodayScreen();
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
