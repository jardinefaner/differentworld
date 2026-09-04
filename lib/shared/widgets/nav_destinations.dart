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
    this.group,
    this.onlyFor,
    this.countProvider,
    this.essential = false,
  });

  final IconData icon;
  final String label;

  /// Where tapping the destination navigates. Always via `context.go`
  /// in both surfaces — these are top-level lateral switches, not
  /// drill-ins, so the nav never stacks routes on top of each other.
  final String route;

  /// Which collapsible group this destination belongs to, by group
  /// title (see [navGroupOrder]). `null` = it's part of the always-
  /// visible spine (the daily-workflow core), rendered flat at the top
  /// of the drawer / rail. A non-null group is tucked one tap away
  /// under a collapsible header so the drawer opens short on a phone.
  final String? group;

  /// If set, the destination only shows when the viewer passes this
  /// check (e.g. Observations needs `canObserve`).
  final bool Function(Viewer viewer)? onlyFor;

  /// Survives the first-week trim (`startingSimpleProvider`).
  ///
  /// The bar is deliberately brutal: a destination is essential only if a
  /// teacher who has been here one day would be worse off without it on
  /// screen. Everything else is still reachable by search and by deep link
  /// — this flag decides what is PUT IN FRONT of someone, not what they are
  /// allowed to do. Marking a fourth or fifth thing essential is how the
  /// wall comes back one plausible item at a time.
  final bool essential;

  /// Optional open-item count shown as a badge (e.g. Captures awaiting
  /// triage, open Tasks). Defined here so both surfaces badge the same
  /// destinations identically. Null → no badge.
  final Provider<int>? countProvider;
}

/// The route pinned to the very bottom of the nav, below every group —
/// Settings is always-present but never competes with the daily spine
/// for the top of the list.
const String navFooterRoute = '/settings';

/// A collapsible nav group — a titled header (with `icon`) over a set of
/// `items`. Built by [buildNavLayout] from the [NavDestination.group]
/// tags so the drawer and rail render identical groupings.
typedef NavGroup = ({String title, IconData icon, List<NavDestination> items});

/// Group headers, in render order. A destination's [NavDestination.group]
/// must match one of these `title`s to be placed; the icon decorates the
/// collapsible header. Order here is the order groups appear below the
/// spine.
const List<({String title, IconData icon})> navGroupOrder = [
  (title: 'Activities', icon: Icons.apps_outlined),
  // NOT Icons.more_horiz — that's the action-overflow "⋯" glyph
  // (overflow_actions.dart); reusing it for a nav group reads as a second
  // "⋯" menu on the desktop rail. A folder/category glyph instead.
  (title: 'More', icon: Icons.category_outlined),
];

/// The structured nav layout both surfaces render: a flat [spine] at the
/// top, the collapsible [groups] in the middle, and a flat [footer]
/// (Settings) pinned at the bottom. Derived from the single
/// [buildNavDestinations] list so the drawer and rail can never drift —
/// they differ only in how they present each band (the drawer collapses
/// groups; the rail, with vertical room to spare, labels them inline).
class NavLayout {
  const NavLayout({
    required this.spine,
    required this.groups,
    required this.footer,
  });

  final List<NavDestination> spine;
  final List<NavGroup> groups;
  final List<NavDestination> footer;
}

/// Split the canonical (capability-filtered) destination list into
/// spine / groups / footer. Empty groups (every item gated out) are
/// dropped so a viewer never sees an empty collapsible header.
NavLayout buildNavLayout(Viewer viewer, {bool startingSimple = false}) {
  final all = buildNavDestinations(viewer, startingSimple: startingSimple);
  final spine = <NavDestination>[];
  final footer = <NavDestination>[];
  final byGroup = <String, List<NavDestination>>{};
  for (final d in all) {
    if (d.route == navFooterRoute) {
      footer.add(d);
    } else if (d.group == null) {
      spine.add(d);
    } else {
      (byGroup[d.group!] ??= <NavDestination>[]).add(d);
    }
  }
  final groups = <NavGroup>[
    for (final g in navGroupOrder)
      if (byGroup[g.title]?.isNotEmpty ?? false)
        (title: g.title, icon: g.icon, items: byGroup[g.title]!),
  ];
  return NavLayout(spine: spine, groups: groups, footer: footer);
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
List<NavDestination> buildNavDestinations(
  Viewer viewer, {
  bool startingSimple = false,
}) {
  final all = <NavDestination>[
    // ── Spine: the daily-workflow core (group: null → always visible,
    //    flat at the top). Six destinations a teacher / director touches
    //    every shift; everything else lives one tap down in a group.
    const NavDestination(
      icon: Icons.today_outlined,
      label: 'Today',
      route: '/',
      essential: true,
    ),
    // Attendance is the first thing a teacher does each morning and it had NO
    // drawer row: it lives at `/groups/:id/attendance`, per-room, so there was
    // nothing flat to link. `/checklist` is the cross-room surface that
    // already exists for exactly this — its omnibox keywords are literally
    // attendance / check-in / morning / mark — and it was reachable only by
    // typing. The most daily action in the app was the hardest to find.
    const NavDestination(
      icon: Icons.task_alt_outlined,
      label: 'Check in',
      route: '/checklist',
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
      essential: true,
    ),
    NavDestination(
      icon: Icons.inbox_outlined,
      label: 'Captures',
      route: '/captures',
      countProvider: _openCapturesCountProvider,
      essential: true,
    ),
    const NavDestination(
      icon: Icons.photo_library_outlined,
      label: 'Photos',
      route: '/photos',
    ),
    const NavDestination(
      icon: Icons.casino_outlined,
      label: 'Pick me',
      route: '/picker',
    ),
    NavDestination(
      icon: Icons.check_circle_outline,
      label: 'Tasks',
      route: '/tasks',
      countProvider: _openTasksCountProvider,
    ),
    const NavDestination(
      icon: Icons.insights_outlined,
      label: 'Insights',
      route: '/insights',
    ),

    // ── Group "Activities": the run-an-activity surfaces. Reached a few
    //    times a day, not every minute — collapsed by default on phone.
    NavDestination(
      icon: Icons.auto_awesome_outlined,
      label: 'Action Words',
      route: '/action-words',
      group: 'Activities',
      onlyFor: (v) => v.canObserve,
    ),
    const NavDestination(
      icon: Icons.psychology_outlined,
      label: 'Tools',
      route: '/tools',
      group: 'Activities',
    ),
    const NavDestination(
      icon: Icons.timer_outlined,
      label: 'Reflect',
      route: '/reflect',
      group: 'Activities',
    ),
    NavDestination(
      icon: Icons.play_circle_outline,
      label: 'Run the day',
      route: '/run-day',
      group: 'Activities',
      onlyFor: (v) => v.canObserve,
    ),
    // ONE entry, because there is one screen. Merging the Present and Brain
    // Breaks hubs left both drawer rows pointing at the same library — two
    // names for one destination, which is the drawer telling a lie about how
    // much app there is. `/present` still resolves for deep links and the
    // omnibox; it just no longer earns a second row.
    const NavDestination(
      icon: Icons.bubble_chart_outlined,
      label: 'Do together',
      route: '/breaks',
      group: 'Activities',
    ),
    const NavDestination(
      icon: Icons.flag_outlined,
      label: 'Missions',
      route: '/settings/missions',
      group: 'Activities',
    ),
    const NavDestination(
      icon: Icons.tv,
      label: 'Brainstorm Board',
      route: '/board',
      group: 'Activities',
    ),

    // ── Group "More": program setup, data collection, and operations —
    //    visited occasionally, so they don't earn a permanent slot.
    NavDestination(
      icon: Icons.map_outlined,
      label: 'Program',
      route: '/program',
      group: 'More',
      onlyFor: (v) => v.canObserve,
    ),
    const NavDestination(
      icon: Icons.quiz_outlined,
      label: 'Surveys',
      route: '/surveys',
      group: 'More',
    ),
    NavDestination(
      icon: Icons.directions_bus_outlined,
      label: 'Vehicles',
      route: '/vehicles',
      group: 'More',
      onlyFor: (v) => v.canDrive || v.canManageSpace,
    ),

    // ── Footer: Settings, pinned to the bottom (see navFooterRoute).
    const NavDestination(
      icon: Icons.settings_outlined,
      label: 'Settings',
      route: '/settings',
    ),
  ].where((d) => d.onlyFor == null || d.onlyFor!(viewer)).toList();

  if (!startingSimple) return all;
  // Settings always survives — it is the only way back out of the trim, and
  // a mode you cannot leave from inside the UI is a trap rather than a
  // starting point.
  //
  // `essential` is already capability-filtered above, which is what makes
  // the trim role-aware for free: a Kitchen Staff member has no
  // Observations to keep, so their three is a different three. A fixed list
  // would have shown everyone the same starting point regardless of what
  // they are allowed to touch — the first thing a newcomer sees promising
  // work they cannot do.
  return [
    for (final d in all)
      if (d.essential || d.route == navFooterRoute) d,
  ];
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
