import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/identity/archetypes.dart';
import 'package:differentworld/features/settings/starting_simple_setting.dart';
import 'package:differentworld/features/today/role_tools.dart';
import 'package:differentworld/shared/widgets/collapsible_section.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/nav_destinations.dart';
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
    // Vertical-aware role label so a construction PM doesn't read as
    // "Project manager" in childcare strings or vice versa.
    final vertical = ref.watch(verticalLabelsProvider).vertical;
    // The self-authored archetype (docs/IDENTITY_SYSTEM.md §2) shows up where
    // identity lives — beside the role line. Decorates, never gates; absent
    // for guardians (no picker) and for anyone who hasn't chosen one.
    final archetype = viewer is GuardianViewer
        ? null
        : archetypeById(viewer.archetypeId);

    // Canonical nav layout — the SAME structure the desktop rail
    // renders, so the two can never drift. Capability gates, badge
    // counts, and grouping all live in nav_destinations; the drawer
    // just renders each band. On a phone the groups collapse so the
    // drawer opens to the short daily spine instead of a 16-item wall.
    final simple = ref.watch(startingSimpleProvider).value ?? false;
    final nav = buildNavLayout(viewer, startingSimple: simple);

    // Role-tailored shortcut cluster — rehomed from Today's old YourToolsStrip
    // (briefing reorg cut it from the home screen; the drawer is the right
    // place for persistent, identity-driven tool access). The archetype
    // re-orders it (Role-3); staff only — guardians get the family lens.
    final tools = viewer is GuardianViewer
        ? const <RoleTool>[]
        : tunedToolsFor(viewer);

    // Wave 54: drawer surface uses the shared GlassPanel so the
    // staff drawer reads as part of the same floating-chrome
    // language as the top pills, the bottom omnibox bar, and the
    // suggestion overlay. Flutter's Drawer wraps the child in its
    // own Material with the DrawerThemeData background — we set the
    // Drawer's backgroundColor + elevation to nil so the GlassPanel
    // is the only visible surface (otherwise the default Material
    // shows behind the glass and defeats the blur).
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: GlassPanel(
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
                                // viewer.displayName routes through
                                // GuardianViewer for guardians (returns
                                // guardian.name) and falls back to
                                // member.displayName for staff. Using the
                                // member field directly was leaving the
                                // guardian avatar with a "?" because the
                                // staff member row carries an email-local-
                                // part placeholder, not their real name.
                                name: () {
                                  final n = viewer.displayName;
                                  return n.isEmpty ? '?' : n;
                                }(),
                                photoUrl: member?.avatarUrl,
                                radius: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      viewer.displayName.isEmpty
                                          ? '—'
                                          : viewer.displayName,
                                      style: theme.textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      () {
                                        final role = viewer is GuardianViewer
                                            ? 'Family'
                                            : RoleLabels.of(
                                                viewer.roleKey,
                                                vertical: vertical,
                                              );
                                        return archetype == null
                                            ? role
                                            : '$role · '
                                                  '${archetype.glyph} '
                                                  '${archetype.name}';
                                      }(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
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

              // Hero "Search anything" tile — the canonical entry point
              // to the omnibox spine. Lives at the top of the drawer so
              // the affordance is the first thing a user sees. The
              // drawer below shrinks to a 5-item top-level orientation
              // list; everything else is in the omnibox.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Material(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      // Capture the router BEFORE popping the drawer — this
                      // tile's context deactivates the instant the drawer
                      // route pops, so a push through it would no-op (the
                      // "post-pop dispatch needs a stable context" invariant).
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop(); // close drawer first
                      unawaited(router.push('/search'));
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Search anything',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(
                                  'Pages, actions, kids, vehicles · Cmd+K',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                            .withValues(alpha: 0.8),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // The daily spine (flat) + the collapsible groups, all
              // scrollable. Groups open collapsed so the drawer lands on
              // the short core list; tap a header to reveal its surfaces.
              // Settings is pinned below the scroll area (see footer).
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final d in nav.spine)
                      _DrawerTile(
                        // Stable per-route key: the list grows / shrinks
                        // with capability gates, so without keys Flutter
                        // would match tiles by position and hand a row's
                        // count subscription to the wrong destination
                        // when a gated item toggles.
                        key: ValueKey('nav-${d.route}'),
                        icon: d.icon,
                        label: d.label,
                        onTap: () => _go(context, d.route),
                        countProvider: d.countProvider,
                      ),
                    // "Your tools" — the role-tailored shortcut cluster
                    // (archetype-ordered). COLLAPSED by default, like the nav
                    // groups, so it never re-lengthens the drawer; tap to
                    // reveal. Self-hides when the role has no tools.
                    // Hidden under the first-week trim. It is one collapsed
                    // row, which is exactly why it is tempting to keep — and
                    // exactly how the wall comes back. The role palette is
                    // tailored to a role you already understand; the person
                    // who needs the trim is the person most likely to open
                    // the mystery drawer and land back in all of it.
                    if (tools.isNotEmpty && !simple)
                      CollapsibleSection(
                        key: const ValueKey('nav-your-tools'),
                        title: archetype == null
                            ? 'Your tools'
                            : 'Your tools  ${archetype.glyph}',
                        icon: Icons.build_outlined,
                        initiallyExpanded: false,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Column(
                            children: [
                              for (final t in tools)
                                _DrawerTile(
                                  key: ValueKey('tool-${t.route}'),
                                  icon: t.icon,
                                  label: t.label,
                                  // Tools can be drill-ins → push, not go.
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    unawaited(context.push(t.route));
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    for (final g in nav.groups)
                      CollapsibleSection(
                        key: ValueKey('nav-group-${g.title}'),
                        title: g.title,
                        icon: g.icon,
                        initiallyExpanded: false,
                        // Indent the group's items so the hierarchy reads
                        // at a glance under the collapsible header.
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Column(
                            children: [
                              for (final d in g.items)
                                _DrawerTile(
                                  key: ValueKey('nav-${d.route}'),
                                  icon: d.icon,
                                  label: d.label,
                                  onTap: () => _go(context, d.route),
                                  countProvider: d.countProvider,
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Footer — Settings pinned to the bottom edge so it's always
              // one tap away regardless of how far the groups expand.
              for (final d in nav.footer)
                _DrawerTile(
                  key: ValueKey('nav-${d.route}'),
                  icon: d.icon,
                  label: d.label,
                  onTap: () => _go(context, d.route),
                  countProvider: d.countProvider,
                ),
              const SizedBox(height: 8),
            ],
          ),
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

class _DrawerTile extends ConsumerWidget {
  const _DrawerTile({
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
  /// drawer), and the parent's watch set stays static regardless of
  /// which destinations the viewer can see. Null → no badge; a zero
  /// count also hides the badge so the row reads as quiet.
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
