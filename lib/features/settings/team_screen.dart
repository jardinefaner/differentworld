import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/invites/widgets/invite_create_sheet.dart';
import 'package:differentworld/features/invites/widgets/invite_share_sheet.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
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
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    // "Invite teammates" is the cap, not the role — a lead-teacher
    // with canInviteStaff = true also gets the invite FAB.
    final canInvite = viewer.canInviteStaff;

    if (spaceId == null) {
      return const EdgeScaffold(
        backFallbackRoute: '/settings',
        body: Center(child: Text('No space selected.')),
      );
    }

    final teamAsync = ref.watch(_teamProvider(spaceId));
    final invitesAsync = ref.watch(pendingInvitesProvider(spaceId));

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      body: teamAsync.when(
        loading: () => const LoadingSlot(),
        error: (e, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load team',
        ),
        data: (members) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(title: 'Team', bottomGap: 8),
              ),
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
                _PendingInvitesHeader(canInvite: canInvite),
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
                          canInvite
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
                          _InviteTile(invite: inv, viewerCanInvite: canInvite),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            );
        },
      ),
      floatingActionButton: canInvite
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
    return ListTile(
      leading: PersonAvatar(
        name: member.displayName,
        photoUrl: member.avatarUrl,
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
  const _PendingInvitesHeader({required this.canInvite});

  final bool canInvite;

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
          if (!canInvite)
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

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.invite, required this.viewerCanInvite});

  final Invite invite;
  final bool viewerCanInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final code = invite.code;
    final email = invite.email;
    final primary = email ?? (code == null ? 'Invite' : _formatCode(code));
    final subtitle = _subtitleFor(invite);

    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: const Icon(Icons.mail_outline),
      ),
      title: Text(primary),
      subtitle: Text(subtitle),
      trailing: viewerCanInvite
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: viewerCanInvite
          ? () => InviteShareSheet.show(context, invite: invite)
          : null,
    );

    if (!viewerCanInvite) return tile;

    // Swipe-left-to-revoke for directors. The dismiss callback awaits a
    // confirm dialog; if declined the tile springs back.
    return Dismissible(
      key: ValueKey('invite-${invite.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => confirmDestructive(
        context,
        title: 'Revoke this invite?',
        message: email == null
            ? 'Code ${_formatCode(code ?? '')} will stop working immediately.'
            : '$email will no longer be able to join with this invite.',
        confirmLabel: 'Revoke',
      ),
      onDismissed: (_) async {
        // Grab the messenger before the await so we don't deref the
        // BuildContext after a possible unmount.
        final messenger = ScaffoldMessenger.of(context);
        await ref.read(inviteActionsProvider).revoke(invite.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Invite revoked'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: tile,
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
