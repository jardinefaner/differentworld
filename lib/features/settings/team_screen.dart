import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lists all members in the signed-in user's space. Tap a row → member
/// detail screen with role + capability editor.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberProvider).value;
    final spaceId = me?.spaceId;
    if (spaceId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team')),
        body: const Center(child: Text('No space selected.')),
      );
    }
    final teamAsync = ref.watch(_teamProvider(spaceId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Text('Team'),
      ),
      body: SafeArea(
        child: teamAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load team',
          ),
          data: (members) {
            if (members.isEmpty) {
              return const EmptyState(
                icon: Icons.groups_outlined,
                title: 'No team members yet',
                message:
                    'Invite teachers and assistants to your program. '
                    '(Invite flow coming soon — for now, ask them to '
                    'sign in with their Google account.)',
              );
            }
            return ListView.separated(
              itemCount: members.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _MemberTile(member: members[i]),
            );
          },
        ),
      ),
    );
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _teamProvider = StreamProvider.autoDispose.family<List<Member>, String>(
  (ref, spaceId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchMembersInSpace(spaceId);
  },
);

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial =
        (member.displayName.trim().isEmpty
                ? '?'
                : member.displayName.trim().substring(0, 1))
            .toUpperCase();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Text(initial),
      ),
      title: Text(member.displayName),
      subtitle: Text(_roleLabel(member.role)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/settings/team/${member.id}'),
    );
  }

  static String _roleLabel(String role) => switch (role) {
    'director' => 'Director',
    'lead_teacher' => 'Lead teacher',
    'teacher' => 'Teacher',
    'assistant' => 'Assistant',
    _ => role,
  };
}
