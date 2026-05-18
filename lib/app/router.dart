import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_screen.dart';
import 'package:differentworld/features/attendance/morning_checklist_screen.dart';
import 'package:differentworld/features/auth/login_screen.dart';
import 'package:differentworld/features/entries/observations_screen.dart';
import 'package:differentworld/features/family/family_today_screen.dart';
import 'package:differentworld/features/groups/group_detail_screen.dart';
import 'package:differentworld/features/groups/group_edit_screen.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:differentworld/features/onboarding/join_or_create_screen.dart';
import 'package:differentworld/features/settings/member_detail_screen.dart';
import 'package:differentworld/features/settings/program_settings_screen.dart';
import 'package:differentworld/features/settings/settings_screen.dart';
import 'package:differentworld/features/settings/team_screen.dart';
import 'package:differentworld/features/subjects/subject_detail_screen.dart';
import 'package:differentworld/features/subjects/subject_edit_screen.dart';
import 'package:differentworld/features/today/today_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_detail_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_edit_screen.dart';
import 'package:differentworld/features/vehicles/vehicle_inspection_screen.dart';
import 'package:differentworld/features/vehicles/vehicles_list_screen.dart';
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
                ],
              ),
            ],
          ),
          // Family-side direct route: a guardian navigates to a child
          // without going through a classroom they don't see.
          GoRoute(
            path: 'children/:sid',
            builder: (_, state) => SubjectDetailScreen(
              subjectId: state.pathParameters['sid']!,
            ),
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
