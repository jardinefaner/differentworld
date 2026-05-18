import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/attendance/attendance_screen.dart';
import 'package:differentworld/features/auth/login_screen.dart';
import 'package:differentworld/features/groups/group_detail_screen.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:differentworld/features/omnibox/omnibox_screen.dart';
import 'package:differentworld/features/onboarding/join_or_create_screen.dart';
import 'package:differentworld/features/settings/member_detail_screen.dart';
import 'package:differentworld/features/settings/program_settings_screen.dart';
import 'package:differentworld/features/settings/settings_screen.dart';
import 'package:differentworld/features/settings/team_screen.dart';
import 'package:differentworld/features/today/today_screen.dart';
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

class _SignedInHome extends ConsumerStatefulWidget {
  const _SignedInHome({super.key});

  @override
  ConsumerState<_SignedInHome> createState() => _SignedInHomeState();
}

/// Home is a horizontal PageView with two pages:
///   page 0 → Omnibox (search / actions)
///   page 1 → Today (default landing)
///
/// Swipe right from Today reveals the Omnibox; swipe left (or tap back)
/// from Omnibox returns to Today.
class _SignedInHomeState extends ConsumerState<_SignedInHome> {
  late final PageController _controller = PageController(initialPage: 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toToday() {
    unawaited(_controller.animateToPage(
      1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    ));
  }

  void _toOmnibox() {
    unawaited(_controller.animateToPage(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
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

    return PageView(
      controller: _controller,
      children: [
        OmniboxScreen(onDismiss: _toToday),
        TodayScreen(onOpenOmnibox: _toOmnibox),
      ],
    );
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
