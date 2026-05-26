import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Wave 121 — persistent left-side navigation panel rendered at
/// desktop widths (>= 1200dp) in place of the hamburger drawer.
///
/// Mobile keeps the existing `MainDrawer` (overlay drawer + hamburger
/// pill); desktop gets this — a fixed 240dp column with the canonical
/// nav destinations pinned in view. The two have separate widget
/// trees so we can iterate on each without touching the other. The
/// destinations + capability gates here mirror what `MainDrawer`
/// surfaces; the slimmer presentation just trades the full identity
/// header / sign-out for a compact icon-row layout that doesn't
/// dominate the page.
///
/// Why not just `NavigationRail`? NavigationRail is built for app-
/// shell-with-tabs where a single index drives which screen is on
/// stage. Our nav targets multiple routes that don't have a single
/// active index (e.g. you can be on `/groups/:id/students/:sid` and
/// "Today" should still feel like a peer destination, not "selected").
/// A custom panel of FeatureCard-style entries reads more honestly
/// for our nav graph.
class DesktopNavRail extends ConsumerWidget {
  const DesktopNavRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final canManage = viewer.canManageSpace;
    final canObserve = viewer.canObserve;
    final canDrive = viewer.canDrive;

    return GlassPanel(
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header — compact identity strip at the top, tap
            // to drill into "my member detail" the same way the mobile
            // drawer does.
            if (viewer.member != null)
              _ProfileHeader(viewer: viewer),
            const Divider(height: 1),
            // Canonical nav. Order: highest-traffic on top.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _NavTile(
                    icon: Icons.today_outlined,
                    label: 'Today',
                    onTap: () => context.go('/'),
                  ),
                  _NavTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Schedule',
                    onTap: () => context.push('/schedule'),
                  ),
                  if (canObserve)
                    _NavTile(
                      icon: Icons.menu_book_outlined,
                      label: 'Observations',
                      onTap: () => context.push('/observations'),
                    ),
                  _NavTile(
                    icon: Icons.bolt_outlined,
                    label: 'Captures',
                    onTap: () => context.push('/captures'),
                  ),
                  _NavTile(
                    icon: Icons.checklist_outlined,
                    label: 'Tasks',
                    onTap: () => context.push('/tasks'),
                  ),
                  _NavTile(
                    icon: Icons.insights_outlined,
                    label: 'Insights',
                    onTap: () => context.push('/insights'),
                  ),
                  _NavTile(
                    icon: Icons.quiz_outlined,
                    label: 'Surveys',
                    onTap: () => context.push('/surveys'),
                  ),
                  if (canDrive || canManage)
                    _NavTile(
                      icon: Icons.directions_bus_outlined,
                      label: 'Vehicles',
                      onTap: () => context.push('/vehicles'),
                    ),
                  const Divider(height: 16),
                  _NavTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.viewer});

  final Viewer viewer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = viewer.member;
    if (m == null) return const SizedBox.shrink();
    final space = viewer.space;
    return InkWell(
      onTap: () => context.push('/settings/team/${m.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Row(
          children: [
            // PersonAvatar handles photo + initials fallback in one
            // widget — no need to switch on avatarUrl presence.
            PersonAvatar(
              name: viewer.displayName,
              photoUrl: m.avatarUrl,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewer.displayName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (space != null)
                    Text(
                      space.name,
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
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      dense: true,
      onTap: onTap,
    );
  }
}
