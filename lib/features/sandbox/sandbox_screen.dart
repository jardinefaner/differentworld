import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/sandbox/sandbox_data.dart';
import 'package:differentworld/features/sandbox/sandbox_scope.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **Try it out** — walk a pretend program without touching the real one.
///
/// Two questions this answers that nothing else can:
///
/// 1. *"Can somebody who has never seen this app get started?"* — the day-one
///    program. A director's very first screen is otherwise impossible to look
///    at again: the starter spine is gated on `onboarding_started`, which only
///    a freshly-created space carries, so an established program can never
///    show it. Without this you would have to sign out and make a real
///    program to review your own first run.
/// 2. *"Can this role actually reach their work?"* — pick a staffer and see
///    their Monday. Role PREVIEW swaps your capabilities but keeps your member
///    id, so your room assignments stay yours, which is why previewing as a
///    counselor usually shows an empty room list. Here you become a real
///    member of a real (pretend) room.
///
/// Safe structurally, not by promise: [SandboxScope] runs everything against
/// an in-memory database with no PowerSync connector, so there is no code path
/// from anything done here to the server.
class SandboxScreen extends ConsumerWidget {
  const SandboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    // Director-only, matching role preview: this shows what other people see,
    // which is a director's question. Not a security boundary — the sandbox
    // holds no real data — but the wrong tool to hand a counselor.
    if (!viewer.isDirector) {
      return const EdgeScaffold(
        body: NoAccess(
          title: 'Try it out',
          message: 'Only a director can open the sandbox.',
        ),
      );
    }

    return EdgeScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          const ContentHeader(
            title: 'Try it out',
            subtitle: 'A pretend program. Nothing here can reach yours.',
          ),
          const SizedBox(height: 8),
          FeatureCard(
            leading: const Icon(Icons.wb_twilight_outlined),
            title: 'Day one',
            subtitle:
                'A program made a minute ago — see what a new '
                'director lands on',
            tone: FeatureCardTone.selected,
            onTap: () => unawaited(context.push('/settings/sandbox/day-one')),
          ),
          const SizedBox(height: 20),
          Text(
            'Or see a running Monday as…',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final staff in sandboxStaff) ...[
            FeatureCard(
              leading: const Icon(Icons.person_outline),
              title: staff.name,
              subtitle: _roleLabel(staff.role),
              onTap: () => unawaited(
                context.push('/settings/sandbox/as/${staff.id}'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

String _roleLabel(String role) => switch (role) {
  'director' => 'Director',
  'lead_teacher' => 'Lead teacher · Sparrows',
  'teacher' => 'Teacher · Sparrows',
  'specialist' => 'Specialist · Herons',
  'substitute' => 'Substitute · Herons',
  _ => role,
};

/// Runs [child] as a pretend staffer inside a throwaway program.
///
/// Overrides `currentMemberProvider` / `currentSpaceProvider` rather than
/// `viewerProvider` itself. Those two are what every downstream provider
/// reads, and `viewerProvider` derives from them — so swapping the source
/// makes the whole graph (rooms, roster, capabilities, the cockpit's beat)
/// resolve against the sandbox naturally, instead of a viewer that claims to
/// be someone the rest of the app can't see.
///
/// `currentMemberProvider` keys off the real auth session's user id, which
/// never matches a pretend `sb-m*` id — so without this override the sandbox
/// would render as a signed-in user with no member row at all.
class SandboxRunScreen extends StatelessWidget {
  const SandboxRunScreen({
    required this.child,
    this.memberId,
    this.day = SandboxDay.running,
    super.key,
  });

  final Widget child;

  /// Which pretend staffer to be. Null for [SandboxDay.dayOne], which has
  /// exactly one member — the director who just made the program.
  final String? memberId;
  final SandboxDay day;

  @override
  Widget build(BuildContext context) {
    return SandboxScope(
      day: day,
      child: _SandboxIdentity(memberId: memberId, child: child),
    );
  }
}

class _SandboxIdentity extends ConsumerWidget {
  const _SandboxIdentity({required this.child, this.memberId});

  final Widget child;
  final String? memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(_sandboxIdentityProvider);
    return rows.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text("Couldn't open the sandbox.")),
      data: (data) {
        final wanted = memberId;
        final member = wanted == null
            ? data.members.firstOrNull
            : data.members.where((m) => m.id == wanted).firstOrNull;
        if (member == null) {
          return const Center(child: Text("Couldn't open the sandbox."));
        }
        return ProviderScope(
          overrides: [
            currentMemberProvider.overrideWith(
              (ref) => Stream<Member?>.value(member),
            ),
            currentSpaceProvider.overrideWith(
              (ref) => Stream<Space?>.value(data.space),
            ),
          ],
          child: child,
        );
      },
    );
  }
}

/// The sandbox's own member + space rows, read through the OVERRIDDEN
/// database — inside [SandboxScope] this resolves to the in-memory one.
final FutureProvider<({List<Member> members, Space? space})>
_sandboxIdentityProvider =
    FutureProvider.autoDispose<({List<Member> members, Space? space})>((
      ref,
    ) async {
      final db = await ref.watch(appDatabaseProvider.future);
      final members = await db.select(db.members).get();
      final space = await db.spacesDao.findById(sandboxSpaceId);
      return (members: members, space: space);
    });
