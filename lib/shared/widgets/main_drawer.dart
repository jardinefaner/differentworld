import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The hamburger menu — opens from the top-left, shows the signed-in
/// user's profile + every primary destination + sign out.
///
/// Drawer (not endDrawer) so the gesture matches the universal
/// "swipe from the left edge" pattern. Programmatic open via the
/// Scaffold key in EdgeScaffold.
class MainDrawer extends ConsumerWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final member = ref.watch(currentMemberProvider).value;
    final space = ref.watch(currentSpaceProvider).value;
    final groupsAsync = ref.watch(groupsProvider);
    final isDirector = member?.role == 'director';

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header — program name + signed-in user.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    space?.name ?? 'Different World',
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PersonAvatar(
                        name: member?.displayName ?? '?',
                        photoUrl: member?.avatarUrl,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member?.displayName ?? '—',
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _roleLabel(member?.role),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Primary destinations.
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerTile(
                    icon: Icons.today_outlined,
                    label: 'Today',
                    onTap: () => _go(context, '/'),
                  ),
                  _DrawerTile(
                    icon: Icons.task_alt,
                    label: 'Morning checklist',
                    onTap: () => _go(context, '/checklist'),
                  ),
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  const _SectionLabel(label: 'Classrooms'),
                  ...groupsAsync.maybeWhen(
                    data: (groups) => groups.isEmpty
                        ? const [
                            Padding(
                              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  const _SectionLabel(label: 'Settings'),
                  if (isDirector)
                    _DrawerTile(
                      icon: Icons.school_outlined,
                      label: 'Program settings',
                      onTap: () => _go(context, '/settings/program'),
                    ),
                  _DrawerTile(
                    icon: Icons.groups_outlined,
                    label: 'Team',
                    onTap: () => _go(context, '/settings/team'),
                  ),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    label: 'All settings',
                    onTap: () => _go(context, '/settings'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Footer — sign out.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DestructiveButton(
                  label: 'Sign out',
                  icon: Icons.logout,
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final auth = ref.read(authActionsProvider);
                    navigator.pop(); // close the drawer first
                    await auth.signOut();
                  },
                ),
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

  static String _roleLabel(String? role) => switch (role) {
        'director' => 'Director',
        'lead_teacher' => 'Lead teacher',
        'teacher' => 'Teacher',
        'assistant' => 'Assistant',
        _ => 'Signed in',
      };
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
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
