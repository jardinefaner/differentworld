import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/invites/widgets/invite_create_sheet.dart';
import 'package:differentworld/features/invites/widgets/invite_share_sheet.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Team screen: members + pending invites in one scroll. Directors get
/// the "Invite teammate" affordance; everyone else sees the same view
/// read-only.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberProvider).value;
    final spaceId = me?.spaceId;
    final isDirector = me?.role == 'director';

    if (spaceId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team')),
        body: const Center(child: Text('No space selected.')),
      );
    }

    final teamAsync = ref.watch(_teamProvider(spaceId));
    final invitesAsync = ref.watch(pendingInvitesProvider(spaceId));

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
            return ListView(
              children: [
                const _SectionLabel(label: 'Members'),
                if (members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text('Nobody here yet.'),
                  )
                else
                  for (final m in members) _MemberTile(member: m),
                const SizedBox(height: 16),
                const Divider(),
                _PendingInvitesHeader(isDirector: isDirector),
                invitesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text('Could not load pending invites.'),
                  ),
                  data: (invites) {
                    if (invites.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Text(
                          isDirector
                              ? 'No pending invites. Tap the button below '
                                  'to invite a teammate.'
                              : 'No pending invites.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final inv in invites)
                          _InviteTile(invite: inv, viewerIsDirector: isDirector),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
      floatingActionButton: isDirector
          ? FloatingActionButton.extended(
              onPressed: () => InviteCreateSheet.show(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Invite'),
            )
          : null,
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
      onTap: () => context.push('/settings/team/${member.id}'),
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

class _PendingInvitesHeader extends StatelessWidget {
  const _PendingInvitesHeader({required this.isDirector});

  final bool isDirector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'PENDING INVITES',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (!isDirector)
            Icon(
              Icons.lock_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite, required this.viewerIsDirector});

  final Invite invite;
  final bool viewerIsDirector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = invite.code;
    final email = invite.email;
    final primary = email ?? (code == null ? 'Invite' : _formatCode(code));
    final subtitle = _subtitleFor(invite);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: const Icon(Icons.mail_outline),
      ),
      title: Text(primary),
      subtitle: Text(subtitle),
      trailing: viewerIsDirector
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: viewerIsDirector
          ? () => InviteShareSheet.show(context, invite: invite)
          : null,
    );
  }

  static String _formatCode(String code) {
    if (code.length == 6) return '${code.substring(0, 3)}-${code.substring(3)}';
    return code;
  }

  static String _subtitleFor(Invite invite) {
    final role = switch (invite.role) {
      'director' => 'Director',
      'lead_teacher' => 'Lead teacher',
      'teacher' => 'Teacher',
      'assistant' => 'Assistant',
      _ => invite.role,
    };
    final expiresLabel = _expiresLabel(invite.expiresAt);
    return '$role · $expiresLabel';
  }

  static String _expiresLabel(String? iso) {
    if (iso == null) return 'Never expires';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Never expires';
    final delta = dt.difference(DateTime.now().toUtc());
    if (delta.isNegative) return 'Expired';
    if (delta.inDays >= 1) return 'Expires in ${delta.inDays}d';
    if (delta.inHours >= 1) return 'Expires in ${delta.inHours}h';
    return 'Expires in ${delta.inMinutes}m';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
