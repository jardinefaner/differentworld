import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/attendance/attendance_screen.dart';
import 'package:differentworld/features/auth/login_screen.dart';
import 'package:differentworld/features/groups/group_detail_screen.dart';
import 'package:differentworld/features/groups/groups_list_screen.dart';
import 'package:differentworld/features/onboarding/create_space_screen.dart';
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
            path: 'groups/:id',
            builder: (_, state) => GroupDetailScreen(
              groupId: state.pathParameters['id']!,
            ),
            routes: [
              GoRoute(
                path: 'attendance',
                builder: (_, state) => AttendanceScreen(
                  groupId: state.pathParameters['id']!,
                ),
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
    final memberAsync = ref.watch(currentMemberProvider);

    return memberAsync.when(
      // The first sync after sign-in: Member row hasn't arrived yet.
      // Show a spinner instead of flashing the onboarding screen.
      loading: _SyncingScaffold.new,
      error: (err, _) => _ErrorScaffold(error: err),
      data: (member) {
        if (member == null) return const _SyncingScaffold();
        if (member.spaceId == null) return const CreateSpaceScreen();
        return const _SignedInHome();
      },
    );
  }
}

class _SignedInHome extends ConsumerWidget {
  const _SignedInHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const GroupsListScreen();
  }
}

class _SyncingScaffold extends StatelessWidget {
  const _SyncingScaffold();

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
  const _ErrorScaffold({required this.error});

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
