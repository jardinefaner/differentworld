import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/role_keys.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
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
        body: EmptyState(
          icon: Icons.group_off_outlined,
          title: 'No space selected',
        ),
      );
    }

    final teamAsync = ref.watch(_teamProvider(spaceId));
    final invitesAsync = ref.watch(pendingInvitesProvider(spaceId));

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: [
        if (canInvite)
          PrimaryActionButton(
            tooltip: 'Invite a teammate',
            icon: Icons.person_add_alt_1,
            onPressed: () => context.push('/settings/team/invite/new'),
          ),
      ],
      body: teamAsync.when(
        loading: () => const LoadingSlot(),
        error: (e, _) => ErrorState(
          title: 'Could not load team',
          onRetry: () => ref.invalidate(_teamProvider(spaceId)),
        ),
        data: (members) {
          return ResponsivePage(
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
                    final theme = Theme.of(context);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (invites.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Text(
                              'No pending invites.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          for (final inv in invites)
                            _InviteTile(invite: inv, viewerCanInvite: canInvite),
                        // Explicit in-body invite affordance for
                        // directors. The same action lives in the
                        // top-right chrome (PrimaryActionButton), but
                        // the chrome icon is easy to miss as a primary
                        // verb — surface it where users are reading.
                        if (canInvite)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            child: FilledButton.icon(
                              onPressed: () => context.push(
                                '/settings/team/invite/new',
                              ),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Invite a teammate'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            );
        },
      ),
      // FAB removed — "Invite a teammate" lives in the top-right
      // primary action above.
    );
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _teamProvider = StreamProvider.autoDispose.family<List<Member>, String>(
  (ref, spaceId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.membersDao.watchInSpace(spaceId);
  },
);

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vertical = ref.watch(verticalLabelsProvider).vertical;
    final roleLabel = RoleLabels.of(member.role, vertical: vertical);
    // For specialists, append the specialty if one is set —
    // "Specialist · Coach" reads more usefully than the bare role.
    // If none is set yet, render "Specialist · choose specialty" in
    // the warning tint so a director can spot incomplete profiles
    // from the list, no per-tile drill-in required.
    final specialty = member.role == RoleKey.specialist
        ? member.caps.getString(ChildcareCaps.specialty)
        : null;
    final hasSpecialty = specialty != null && specialty.isNotEmpty;
    final isSpecialistMissingSpecialty =
        member.role == RoleKey.specialist && !hasSpecialty;

    final Widget subtitle;
    if (isSpecialistMissingSpecialty) {
      // Two-segment subtitle: role in normal tone, "choose specialty"
      // hint in tertiary so it reads as a soft "please complete."
      subtitle = Text.rich(
        TextSpan(
          children: [
            TextSpan(text: roleLabel),
            const TextSpan(text: ' · '),
            TextSpan(
              text: 'choose specialty',
              style: TextStyle(color: scheme.tertiary),
            ),
          ],
        ),
      );
    } else if (hasSpecialty) {
      subtitle = Text('$roleLabel · ${SpecialtyKeys.labelOf(specialty)}');
    } else {
      subtitle = Text(roleLabel);
    }
    return ListTile(
      leading: PersonAvatar(
        name: member.displayName,
        photoUrl: member.avatarUrl,
      ),
      title: Text(member.displayName),
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/settings/team/${member.id}'),
    );
  }
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
    final vertical = ref.watch(verticalLabelsProvider).vertical;
    final subtitle = _subtitleFor(invite, vertical: vertical);

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
          ? () => context.push(
                '/settings/team/invite/${invite.id}',
                extra: invite,
              )
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

  static String _subtitleFor(Invite invite, {required String vertical}) {
    // Route through the agnostic RoleLabels so a hospitality
    // invite reads "Manager" not the previous hardcoded "Lead
    // teacher" etc.
    final role = RoleLabels.of(invite.role, vertical: vertical);
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
