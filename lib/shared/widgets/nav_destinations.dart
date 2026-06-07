import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single canonical navigation destination list — shared between
/// `MainDrawer` (mobile / tablet) and `DesktopNavRail` (desktop).
///
/// Any time a top-level route is added, update THIS file and both
/// surfaces inherit it — no more drift between drawer and rail.
///
/// Each surface renders the list in its own visual idiom (the drawer
/// uses whitespace for section breaks, the rail uses divider lines),
/// but the destinations, order, icons, capability gates, and badge
/// counts are defined once, here.

class NavDestination {
  const NavDestination({
    required this.icon,
    required this.label,
    required this.route,
    this.dividerBefore = false,
    this.onlyFor,
    this.countProvider,
  });

  final IconData icon;
  final String label;

  /// Where tapping the destination navigates. Always via `context.go`
  /// in both surfaces — these are top-level lateral switches, not
  /// drill-ins, so the nav never stacks routes on top of each other.
  final String route;

  /// Mark a section break above this item. The drawer renders it as
  /// extra whitespace (it has no divider lines by design); the rail
  /// renders it as a [Divider].
  final bool dividerBefore;

  /// If set, the destination only shows when the viewer passes this
  /// check (e.g. Observations needs `canObserve`).
  final bool Function(Viewer viewer)? onlyFor;

  /// Optional open-item count shown as a badge (e.g. Captures awaiting
  /// triage, open Tasks). Defined here so both surfaces badge the same
  /// destinations identically. Null → no badge.
  final Provider<int>? countProvider;
}

/// Open-captures count (items awaiting triage) — surfaced as a badge so
/// the user sees inbox depth without opening the screen.
///
/// `autoDispose` is load-bearing: [openCapturesProvider] is a
/// `StreamProvider.autoDispose`, so a non-disposing intermediate would
/// pin its Drift stream alive for the whole app lifetime. Keeping this
/// intermediate auto-disposing means the count stream lives exactly as
/// long as a drawer / rail is actually watching it — the same scope the
/// drawer's old inline `ref.watch` had. (Declared as `Provider<int>` for
/// a nameable type; the instance is still auto-disposing at runtime.)
final Provider<int> _openCapturesCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(openCapturesProvider).value?.length ?? 0,
);

/// Open-tasks count. Same autoDispose rationale as captures above.
final Provider<int> _openTasksCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(openTasksProvider).value?.length ?? 0,
);

/// All top-level destinations, in canonical order (highest-traffic
/// first), filtered to those the [viewer] can access. Capability-gated
/// items carry [NavDestination.onlyFor]; Settings is always last,
/// preceded by a section break.
List<NavDestination> buildNavDestinations(Viewer viewer) {
  return <NavDestination>[
    // ── Daily workflow ──────────────────────────────────────────────
    const NavDestination(
      icon: Icons.today_outlined,
      label: 'Today',
      route: '/',
    ),
    const NavDestination(
      icon: Icons.calendar_month_outlined,
      label: 'Schedule',
      route: '/schedule',
    ),
    NavDestination(
      icon: Icons.menu_book_outlined,
      label: 'Observations',
      route: '/observations',
      onlyFor: (v) => v.canObserve,
    ),
    NavDestination(
      icon: Icons.auto_awesome_outlined,
      label: 'Action Words',
      route: '/action-words',
      onlyFor: (v) => v.canObserve,
    ),
    NavDestination(
      icon: Icons.inbox_outlined,
      label: 'Captures',
      route: '/captures',
      countProvider: _openCapturesCountProvider,
    ),
    NavDestination(
      icon: Icons.check_circle_outline,
      label: 'Tasks',
      route: '/tasks',
      countProvider: _openTasksCountProvider,
    ),

    // ── Activities ──────────────────────────────────────────────────
    const NavDestination(
      icon: Icons.psychology_outlined,
      label: 'Tools',
      route: '/tools',
    ),
    const NavDestination(
      icon: Icons.co_present_outlined,
      label: 'Present',
      route: '/present',
    ),
    const NavDestination(
      icon: Icons.bubble_chart_outlined,
      label: 'Brain Breaks',
      route: '/breaks',
    ),
    const NavDestination(
      icon: Icons.flag_outlined,
      label: 'Missions',
      route: '/settings/missions',
    ),
    const NavDestination(
      icon: Icons.tv,
      label: 'Brainstorm Board',
      route: '/board',
    ),

    // ── Insights + data ─────────────────────────────────────────────
    const NavDestination(
      icon: Icons.insights_outlined,
      label: 'Insights',
      route: '/insights',
    ),
    const NavDestination(
      icon: Icons.quiz_outlined,
      label: 'Surveys',
      route: '/surveys',
    ),

    // ── Operations ──────────────────────────────────────────────────
    NavDestination(
      icon: Icons.directions_bus_outlined,
      label: 'Vehicles',
      route: '/vehicles',
      onlyFor: (v) => v.canDrive || v.canManageSpace,
    ),

    // ── Settings (always last) ──────────────────────────────────────
    const NavDestination(
      icon: Icons.settings_outlined,
      label: 'Settings',
      route: '/settings',
      dividerBefore: true,
    ),
  ].where((d) => d.onlyFor == null || d.onlyFor!(viewer)).toList();
}

/// The open-count badge shown on the trailing edge of a nav tile.
/// Shared so the drawer and rail render counts identically. Zero is
/// never passed here — callers hide the badge entirely at zero so a
/// destination reads as quiet when nothing is pending.
class NavCountBadge extends StatelessWidget {
  const NavCountBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
