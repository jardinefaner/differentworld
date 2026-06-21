import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/role_keys.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/master_detail_scaffold.dart';
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the short member rows re-lay as a dense
    // 2-up card grid (over the SAME _teamProvider data); the text-heavy /
    // swipe-interactive pending-invites section stays a full-width list. Off
    // keeps the existing single-column scroll. Master-detail + every action
    // are untouched either way.
    final bento = bentoEnabled(ref, perScreen: null);

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
    // Wave 118: ?selected=<id> from the URL drives the right-pane
    // member summary at desktop widths. Refresh / share / browser-
    // back all preserve it because it lives in the URL, not in
    // local state.
    final selectedId =
        GoRouterState.of(context).uri.queryParameters['selected'];

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
          // The list column — same content as the old single-column
          // scroll, but each _MemberTile now respects selection
          // highlighting and the master-detail tap routing.
          final list = ResponsivePage(
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
              else if (bento)
                // SAME members, re-laid as a dense 2-up card grid (≈210dp
                // cells). Each cell reuses the member identity + role + tap
                // routing as the flat tile; only the shape is compact.
                _MemberGrid(
                  members: members,
                  selectedId: selectedId,
                )
              else
                for (final m in members)
                  _MemberTile(
                    member: m,
                    selectedId: selectedId,
                  ),
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
                          _InviteTile(
                            invite: inv,
                            viewerCanInvite: canInvite,
                          ),
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

          // The detail pane: a compact summary of the selected
          // member with a CTA into the full edit screen. Compact
          // on purpose — this is the at-a-glance pane, not a
          // replacement for the full /settings/team/<id> route
          // where every cap + cert lives.
          final selectedMember = selectedId == null
              ? null
              : members.where((m) => m.id == selectedId).firstOrNull;
          final detail = selectedMember == null
              ? null
              : _MemberSummaryPanel(member: selectedMember);

          return MasterDetailScaffold(
            list: list,
            detail: detail,
            // Wider left rail than the default 360dp — member list
            // rows are dense (avatar + 2-line subtitle + chevron).
            listWidth: 420,
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
  const _MemberTile({required this.member, this.selectedId});

  final Member member;

  /// Wave 118: when non-null, the tile whose `member.id` matches
  /// renders with a selected background. Drives the master-detail
  /// left-rail highlight on wide windows.
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vertical = ref.watch(verticalLabelsProvider).vertical;
    final roleLabel = RoleLabels.of(member.role, vertical: vertical);
    // For specialists, append the specialty if one is set — shared with the
    // bento card so the two layouts never drift.
    final subtitle = _memberRoleSubtitle(member, roleLabel, scheme);
    // Wave 118: master-detail tap routing. On wide windows (≥1200dp,
    // matching MasterDetailScaffold's collapseAt) update the URL
    // with `?selected=<id>` so the right pane reflects the selection
    // without a route push. On narrow, keep the drill-in to the
    // full /settings/team/<id> route.
    final isSelected = selectedId == member.id;
    final isWide =
        MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    return ListTile(
      leading: PersonAvatar(
        name: member.displayName,
        photoUrl: member.avatarUrl,
      ),
      title: EntityLink(
        entity: EntityRef(
          kind: EntityKind.member,
          id: member.id,
          label: member.displayName,
        ),
        padded: false,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: subtitle,
      selected: isSelected,
      selectedTileColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        if (isWide) {
          context.replace('/settings/team?selected=${member.id}');
        } else {
          unawaited(context.push('/settings/team/${member.id}'));
        }
      },
    );
  }
}

/// The member's role line, with the specialist-specialty handling shared by
/// the flat [_MemberTile] and the bento [_MemberCard] so they never drift:
/// "Specialist · Coach" when set, or "Specialist · choose specialty" in the
/// tertiary tint so a director spots incomplete profiles from the list.
Widget _memberRoleSubtitle(Member member, String roleLabel, ColorScheme scheme) {
  final specialty = member.role == RoleKey.specialist
      ? member.caps.getString(ChildcareCaps.specialty)
      : null;
  final hasSpecialty = specialty != null && specialty.isNotEmpty;
  final isSpecialistMissingSpecialty =
      member.role == RoleKey.specialist && !hasSpecialty;
  if (isSpecialistMissingSpecialty) {
    return Text.rich(
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
  }
  if (hasSpecialty) {
    return Text('$roleLabel · ${SpecialtyKeys.labelOf(specialty)}');
  }
  return Text(roleLabel);
}

/// Bento-path members: SAME list, re-laid as a dense card grid that's 2-up on
/// a phone (≈210dp cells), more across wider screens. The member set is small
/// and bounded, so a shrink-wrapping grid (the present-hub pattern) is fine
/// inside the outer scroll — `mainAxisExtent` bounds each cell so the card's
/// shrink-wrapping Column is safe.
class _MemberGrid extends StatelessWidget {
  const _MemberGrid({required this.members, this.selectedId});

  final List<Member> members;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GridView.builder(
        shrinkWrap: true,
        primary: false,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 210,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // Bounded height: avatar + name + role line. Roomy enough that a
          // two-line role ("Specialist · choose specialty") doesn't clip.
          mainAxisExtent: 132,
        ),
        itemCount: members.length,
        itemBuilder: (context, i) {
          final m = members[i];
          return _MemberCard(
            key: ValueKey('member-card-${m.id}'),
            member: m,
            selectedId: selectedId,
          );
        },
      ),
    );
  }
}

/// One member as a compact bento card — avatar + name + role. Reuses the exact
/// identity, role subtitle, and master-detail tap routing of [_MemberTile];
/// only the shape (vertical card) differs so it fits a 2-up grid cell.
class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.member, this.selectedId, super.key});

  final Member member;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vertical = ref.watch(verticalLabelsProvider).vertical;
    final roleLabel = RoleLabels.of(member.role, vertical: vertical);
    final isSelected = selectedId == member.id;
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    return Material(
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isWide) {
            context.replace('/settings/team?selected=${member.id}');
          } else {
            unawaited(context.push('/settings/team/${member.id}'));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PersonAvatar(
                name: member.displayName,
                photoUrl: member.avatarUrl,
              ),
              const SizedBox(height: 10),
              EntityLink(
                entity: EntityRef(
                  kind: EntityKind.member,
                  id: member.id,
                  label: member.displayName,
                ),
                padded: false,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              DefaultTextStyle.merge(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                child: _memberRoleSubtitle(member, roleLabel, scheme),
              ),
            ],
          ),
        ),
      ),
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

    // Wave 112: trailing PopupMenuButton (icon: more_vert) so a
    // director on desktop has a visible mouse path to Revoke. The
    // swipe gesture below is still the mobile accelerator, but
    // shipping destructive-action-via-swipe-only meant a desktop
    // user had no path to revoke. Tap the menu → Revoke → same
    // confirmDestructive + revoke flow the Dismissible uses.
    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: const Icon(Icons.mail_outline),
      ),
      title: Text(primary),
      subtitle: Text(subtitle),
      trailing: viewerCanInvite
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) async {
                    if (v != 'revoke') return;
                    final messenger = ScaffoldMessenger.of(context);
                    final confirmed = await confirmDestructive(
                      context,
                      title: 'Revoke this invite?',
                      message: email == null
                          ? 'Code ${_formatCode(code ?? '')} will stop '
                              'working immediately.'
                          : '$email will no longer be able to join with '
                              'this invite.',
                      confirmLabel: 'Revoke',
                    );
                    if (!confirmed) return;
                    await ref
                        .read(inviteActionsProvider)
                        .revoke(invite.id);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Invite revoked'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'revoke',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 12),
                          Text('Revoke'),
                        ],
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.chevron_right),
              ],
            )
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

/// Wave 118: the right-pane summary card for `/settings/team` master-
/// detail. Renders the selected member's identity + role at a glance,
/// with a CTA into the full edit screen. Compact on purpose — the
/// full editing surface (cap toggles, certifications, danger zone)
/// still lives at `/settings/team/<id>` where it has the screen
/// estate to breathe. This pane is for "who is this person?" reads
/// the director does scanning the roster, not for editing.
class _MemberSummaryPanel extends ConsumerWidget {
  const _MemberSummaryPanel({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vertical = ref.watch(verticalLabelsProvider).vertical;
    final roleLabel = RoleLabels.of(member.role, vertical: vertical);
    final caps = member.caps;
    final actsAsDirector = caps.getBool(CoreCaps.canActAsDirector);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonAvatar(
                name: member.displayName,
                photoUrl: member.avatarUrl,
                radius: 56,
              ),
              const SizedBox(height: 16),
              Text(
                member.displayName,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                roleLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (actsAsDirector) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: Icon(
                    Icons.verified_user_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  label: const Text('Acts as director'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    context.push('/settings/team/${member.id}'),
                icon: const Icon(Icons.tune),
                label: const Text('Open full settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
