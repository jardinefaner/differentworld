import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart' show Entry;
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_screen.dart';
import 'package:differentworld/features/attendance/morning_checklist_screen.dart';
import 'package:differentworld/features/auth/login_screen.dart';
import 'package:differentworld/features/captures/capture_inbox_screen.dart';
import 'package:differentworld/features/captures/capture_screen.dart';
import 'package:differentworld/features/entries/observation_form_screen.dart';
import 'package:differentworld/features/entries/observations_index_screen.dart';
import 'package:differentworld/features/entries/observations_screen.dart';
import 'package:differentworld/features/exports/progress_report_screen.dart';
import 'package:differentworld/features/family/family_messages_screen.dart';
import 'package:differentworld/features/family/family_subject_detail_screen.dart';
import 'package:differentworld/features/family/family_today_screen.dart';
import 'package:differentworld/features/groups/group_detail_screen.dart';
import 'package:differentworld/features/groups/group_edit_screen.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:differentworld/features/messages/message_thread_screen.dart';
import 'package:differentworld/features/omnibox/omnibox_search_screen.dart';
import 'package:differentworld/features/onboarding/join_or_create_screen.dart';
import 'package:differentworld/features/review/weekly_review_screen.dart';
import 'package:differentworld/features/review/yearly_review_screen.dart';
import 'package:differentworld/features/schedule/activities_list_screen.dart';
import 'package:differentworld/features/schedule/activity_edit_screen.dart';
import 'package:differentworld/features/schedule/locations_list_screen.dart';
import 'package:differentworld/features/schedule/schedule_screen.dart';
import 'package:differentworld/features/settings/member_detail_screen.dart';
import 'package:differentworld/features/settings/program_settings_screen.dart';
import 'package:differentworld/features/settings/settings_screen.dart';
import 'package:differentworld/features/settings/team_screen.dart';
import 'package:differentworld/features/subjects/subject_detail_screen.dart';
import 'package:differentworld/features/subjects/subject_edit_screen.dart';
import 'package:differentworld/features/surveys/survey_list_screen.dart';
import 'package:differentworld/features/surveys/survey_table_screen.dart';
import 'package:differentworld/features/surveys/survey_take_screen.dart';
import 'package:differentworld/features/tasks/task_screen.dart';
import 'package:differentworld/features/tasks/tasks_screen.dart';
import 'package:differentworld/features/today/today_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_detail_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_edit_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_inspection_screen.dart';
import 'package:differentworld/features/vehicles/vehicles_list_screen.dart';
import 'package:differentworld/shared/widgets/app_shell.dart';
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
    redirect: (context, state) {
      final isSignedIn = ref.read(isSignedInProvider);
      final goingToAuth = state.matchedLocation.startsWith('/login');
      if (!isSignedIn && !goingToAuth) return '/login';
      if (isSignedIn && goingToAuth) return '/';
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
        builder: (_, _) => const _Home(),
        routes: [
          GoRoute(
            path: 'checklist',
            builder: (_, state) => MorningChecklistScreen(
              initialFilter: state.uri.queryParameters['filter'],
            ),
          ),
          GoRoute(
            path: 'groups/new',
            builder: (_, _) => const GroupEditScreen(),
          ),
          GoRoute(
            path: 'groups/:id',
            builder: (_, state) => GroupDetailScreen(
              groupId: state.pathParameters['id']!,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => GroupEditScreen(
                  groupId: state.pathParameters['id'],
                ),
              ),
              GoRoute(
                path: 'attendance',
                builder: (_, state) => AttendanceScreen(
                  groupId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'observations',
                builder: (_, state) => ObservationsScreen(
                  groupId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'students/new',
                builder: (_, state) => SubjectEditScreen(
                  groupId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'students/:sid',
                builder: (_, state) => SubjectDetailScreen(
                  subjectId: state.pathParameters['sid']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => SubjectEditScreen(
                      groupId: state.pathParameters['id']!,
                      subjectId: state.pathParameters['sid'],
                    ),
                  ),
                  // Progress-report PDF — preview + share/print.
                  // Reached from the staff subject detail screen.
                  GoRoute(
                    path: 'progress-report',
                    builder: (_, state) => ProgressReportScreen(
                      subjectId: state.pathParameters['sid']!,
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
            builder: (_, _) => const ObservationsIndexScreen(),
            routes: [
              // Create-observation route (Wave 21, replaces the old
              // `ObservationFormSheet.show`). Query params let the
              // caller pre-fill groupId + subjectId.
              GoRoute(
                path: 'new',
                builder: (_, state) {
                  final q = state.uri.queryParameters;
                  return ObservationFormScreen(
                    groupId: q['groupId'],
                    initialSubjectId: q['subjectId'],
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
                  return ObservationFormScreen(
                    existing: entry is Entry ? entry : null,
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
            builder: (_, _) => const InsightsScreen(),
          ),
          // Capture inbox — the upward loop's *input* side. Quick
          // "I noticed…" notes awaiting triage into observations
          // or dismissal.
          GoRoute(
            path: 'captures',
            builder: (_, _) => const CaptureInboxScreen(),
            routes: [
              // New-capture surface as a real route (Wave 21,
              // replaces the old `showCaptureSheet` bottom-sheet).
              GoRoute(
                path: 'new',
                builder: (_, _) => const CaptureScreen(),
              ),
            ],
          ),
          // Tasks — the third capture-promotion destination, and a
          // standalone to-do list for the program.
          GoRoute(
            path: 'tasks',
            builder: (_, _) => const TasksScreen(),
            routes: [
              // New-task surface as a real route (Wave 21,
              // replaces the old `showNewTaskSheet` bottom-sheet).
              GoRoute(
                path: 'new',
                builder: (_, _) => const TaskScreen(),
              ),
            ],
          ),
          // Messages — `/messages` is the family-side index (one row
          // per linked child). Threads themselves are reached at
          // `/messages/:subjectId/:guardianId` from either the family
          // index or the staff subject_detail.
          GoRoute(
            path: 'messages',
            builder: (_, _) => const FamilyMessagesScreen(),
          ),
          GoRoute(
            path: 'messages/:subjectId/:guardianId',
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
            builder: (_, _) => const WeeklyReviewScreen(),
            routes: [
              // Yearly review — the long-tempo Foundation re-grounding.
              // A calm snapshot + three open-ended prompts; no data to
              // submit, just orientation.
              GoRoute(
                path: 'year',
                builder: (_, _) => const YearlyReviewScreen(),
              ),
            ],
          ),
          // Surveys — index of templates + per-template list of kids
          // + take-survey flow.
          GoRoute(
            path: 'surveys',
            builder: (_, _) => const SurveyIndexScreen(),
            routes: [
              GoRoute(
                path: ':templateId',
                builder: (_, state) => SurveyTemplateDetailScreen(
                  templateId: state.pathParameters['templateId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'take/:subjectId',
                    builder: (_, state) => SurveyTakeScreen(
                      templateId: state.pathParameters['templateId']!,
                      subjectId: state.pathParameters['subjectId']!,
                    ),
                  ),
                  // Spreadsheet review across kids — director scans
                  // patterns and exports CSV.
                  GoRoute(
                    path: 'table',
                    builder: (_, state) => SurveyTableScreen(
                      templateId: state.pathParameters['templateId']!,
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
            builder: (_, state) => FamilySubjectDetailScreen(
              subjectId: state.pathParameters['sid']!,
            ),
          ),
          // Camp scheduling — staff-facing.
          GoRoute(
            path: 'schedule',
            builder: (_, _) => const ScheduleScreen(),
          ),
          GoRoute(
            path: 'activities',
            builder: (_, _) => const ActivitiesListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const ActivityEditScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => ActivityEditScreen(
                  activityId: state.pathParameters['id'],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'program',
            builder: (_, _) => const ProgramSettingsScreen(),
          ),
          GoRoute(
            path: 'locations',
            builder: (_, _) => const LocationsListScreen(),
          ),
          GoRoute(
            path: 'team',
            builder: (_, _) => const TeamScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => MemberDetailScreen(
                  memberId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'vehicles',
            builder: (_, _) => const VehiclesListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const VehicleEditScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => VehicleDetailScreen(
                  vehicleId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => VehicleEditScreen(
                      vehicleId: state.pathParameters['id'],
                    ),
                  ),
                  GoRoute(
                    path: 'checkout',
                    builder: (_, state) => VehicleInspectionScreen(
                      vehicleId: state.pathParameters['id']!,
                      kind: 'checkout',
                    ),
                  ),
                  GoRoute(
                    path: 'checkin',
                    builder: (_, state) => VehicleInspectionScreen(
                      vehicleId: state.pathParameters['id']!,
                      kind: 'checkin',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
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
        ],
      ),
    ],
  );
});

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
/// used to occupy is gone. We still need a stateful host here because
/// the home is where we listen for pending invite codes that arrive
/// while the user already has a space (refuse cleanly + snackbar).
class _SignedInHome extends ConsumerWidget {
  const _SignedInHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A signed-in user with a space can't redeem an invite — refuse
    // cleanly and clear the pending code so they aren't bounced into
    // some other state. Switching programs is a sign-out-and-back-in
    // workflow for now.
    ref.listen<String?>(pendingInviteCodeProvider, (prev, next) {
      if (next == null || next.isEmpty) return;
      ref.read(pendingInviteCodeProvider.notifier).clear();
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            "You're already in a program. Sign out first to join a "
            'different one.',
          ),
        ),
      );
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
                error.toString(),
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
