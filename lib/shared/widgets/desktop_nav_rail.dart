import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/settings/starting_simple_setting.dart';
import 'package:differentworld/shared/widgets/collapsible_section.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/nav_destinations.dart';
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
/// trees so we can iterate on each without touching the other, but
/// they pull their destinations, order, capability gates, and badge
/// counts from the SAME source ([buildNavDestinations]) so the two
/// can never drift. Only the presentation differs — the rail is a
/// compact always-on column, the drawer an overlay.
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

    // Canonical nav layout — the SAME structure the mobile drawer
    // renders, so the two can never drift. Capability gates, badge
    // counts, and grouping live in nav_destinations; the rail just
    // renders each band. Desktop has the vertical room, so groups start
    // expanded here (still collapsible for a user who wants focus) where
    // the phone drawer opens them collapsed.
    final simple = ref.watch(startingSimpleProvider).value ?? false;
    final nav = buildNavLayout(viewer, startingSimple: simple);

    return GlassPanel(
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header — compact identity strip at the top, tap
            // to drill into "my member detail" the same way the mobile
            // drawer does; sign-out lives on the trailing edge.
            if (viewer.member != null) _ProfileHeader(viewer: viewer),
            const Divider(height: 1),
            // Spine (flat) + collapsible groups, scrollable; Settings is
            // pinned below so it sits at the rail's bottom edge.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final d in nav.spine)
                    _NavTile(
                      // Stable per-route key — the list grows / shrinks
                      // with capability gates; without keys Flutter would
                      // match tiles by position and hand a row's count
                      // subscription to the wrong destination when a
                      // gated item toggles.
                      key: ValueKey('nav-${d.route}'),
                      icon: d.icon,
                      label: d.label,
                      onTap: () => context.go(d.route),
                      countProvider: d.countProvider,
                    ),
                  for (final g in nav.groups)
                    CollapsibleSection(
                      key: ValueKey('nav-group-${g.title}'),
                      title: g.title,
                      icon: g.icon,
                      child: Column(
                        children: [
                          for (final d in g.items)
                            _NavTile(
                              key: ValueKey('nav-${d.route}'),
                              icon: d.icon,
                              label: d.label,
                              onTap: () => context.go(d.route),
                              countProvider: d.countProvider,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final d in nav.footer)
              _NavTile(
                key: ValueKey('nav-${d.route}'),
                icon: d.icon,
                label: d.label,
                onTap: () => context.go(d.route),
                countProvider: d.countProvider,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.viewer});

  final Viewer viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final m = viewer.member;
    if (m == null) return const SizedBox.shrink();
    final space = viewer.space;
    return InkWell(
      onTap: () => context.push('/settings/team/${m.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 12),
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
            // Sign-out parity with the mobile drawer. The rail is
            // persistent (no overlay to pop) so this just signs out.
            IconButton(
              tooltip: 'Sign out',
              icon: Icon(
                Icons.logout,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () async {
                await ref.read(authActionsProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends ConsumerWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.countProvider,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Source of the open-item count badge. The tile watches it itself
  /// so only this row rebuilds when the count changes (not the whole
  /// persistent rail), and the parent's watch set stays static. Null →
  /// no badge; a zero count also hides the badge — same convention as
  /// the mobile drawer.
  final Provider<int>? countProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = countProvider == null ? 0 : ref.watch(countProvider!);
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      dense: true,
      onTap: onTap,
      trailing: count == 0 ? null : NavCountBadge(count: count),
    );
  }
}
