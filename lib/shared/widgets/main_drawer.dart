import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The hamburger menu. Opens from the top-left edge.
///
/// Layout decisions:
/// - No visible divider lines. Sections are separated by whitespace +
///   small uppercase labels.
/// - The header is a single tappable row: avatar + name + role on the
///   left (tap → your profile), sign-out icon on the right.
/// - Program name sits above the profile row as a small breadcrumb so
///   the user can see which space they're in at a glance.
class MainDrawer extends ConsumerWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final member = viewer.member;
    final space = viewer.space;
    final groupsAsync = ref.watch(groupsProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header — program breadcrumb + profile row.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (space != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        space.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Profile row: tap the row → your own member detail;
                  // tap the icon at the right → sign out.
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: member == null
                          ? null
                          : () {
                              Navigator.of(context).pop(); // close drawer
                              unawaited(
                                context.push('/settings/team/${member.id}'),
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                        child: Row(
                          children: [
                            PersonAvatar(
                              name: member?.displayName ?? '?',
                              photoUrl: member?.avatarUrl,
                              radius: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member?.displayName ?? '—',
                                    style: theme.textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    viewer.roleLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Sign out',
                              icon: Icon(
                                Icons.logout,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () async {
                                final navigator = Navigator.of(context);
                                final auth = ref.read(authActionsProvider);
                                navigator.pop(); // close drawer
                                await auth.signOut();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Destinations.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _DrawerTile(
                    icon: Icons.today_outlined,
                    label: 'Today',
                    onTap: () => _go(context, '/'),
                  ),
                  if (viewer.isDailyLogger)
                    _DrawerTile(
                      icon: Icons.task_alt,
                      label: 'Morning checklist',
                      onTap: () => _go(context, '/checklist'),
                    ),

                  const _SectionGap(),
                  const _SectionLabel(label: 'Classrooms'),
                  ...groupsAsync.maybeWhen(
                    data: (groups) => groups.isEmpty
                        ? const [
                            Padding(
                              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                              child: Text(
                                'No classrooms yet.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ]
                        : groups
                            .map(
                              (g) => _DrawerTile(
                                icon: Icons.meeting_room_outlined,
                                label: g.name,
                                subtitle: g.ageRange,
                                onTap: () =>
                                    _go(context, '/groups/${g.id}'),
                              ),
                            )
                            .toList(),
                    orElse: () => const [SizedBox.shrink()],
                  ),

                  if (viewer.canSeeTeam ||
                      viewer.canManageProgram ||
                      viewer.showsBilling) ...[
                    const _SectionGap(),
                    const _SectionLabel(label: 'Program'),
                  ],
                  if (viewer.canSeeTeam)
                    _DrawerTile(
                      icon: Icons.groups_outlined,
                      label: 'Team',
                      onTap: () => _go(context, '/settings/team'),
                    ),
                  if (viewer.canManageProgram)
                    _DrawerTile(
                      icon: Icons.school_outlined,
                      label: 'Program settings',
                      onTap: () => _go(context, '/settings/program'),
                    ),
                  if (viewer.showsBilling)
                    _DrawerTile(
                      icon: Icons.receipt_long_outlined,
                      label: 'Billing',
                      onTap: () => _go(context, '/settings'),
                    ),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    label: 'All settings',
                    onTap: () => _go(context, '/settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop(); // close drawer
    // Use go for top-level destinations from the drawer — the user
    // chose where to be, no stack to preserve.
    context.go(route);
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      dense: subtitle == null,
      onTap: onTap,
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 16);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
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
