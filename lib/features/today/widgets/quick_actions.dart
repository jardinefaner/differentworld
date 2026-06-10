import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "New observation" entry point shared by [QuickActions] and the
/// omnibox search. Resolves the classroom context automatically:
///   - 0 visible classrooms → "you're not assigned" snackbar
///   - 1 visible classroom → opens the form for that group directly
///   - 2+ → shows a transient classroom picker, then the form
///
/// Kept as a top-level function so any new launchpad surface (search,
/// QuickActions, etc.) routes through the same flow — no divergence.
Future<void> startNewObservation(BuildContext context, WidgetRef ref) async {
  final groupsAsync = ref.read(groupsProvider);
  final groups = groupsAsync.value ?? const <Group>[];
  if (groups.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("You're not assigned to a classroom yet."),
      ),
    );
    return;
  }
  if (groups.length == 1) {
    unawaited(
      context.push('/observations/new?groupId=${groups.first.id}'),
    );
    return;
  }
  final picked = await _ClassroomPickerSheet.show(context, groups: groups);
  if (picked == null || !context.mounted) return;
  unawaited(context.push('/observations/new?groupId=${picked.id}'));
}

/// Capability-aware row of one-tap action tiles on the Today screen.
///
/// **Hide, don't disable.** Each tile renders only when tapping it
/// would succeed — both the permission cap AND the runtime
/// preconditions (assignments / data) have to be satisfied. A
/// teacher with `canObserve` but no assigned classrooms sees no
/// "New observation" tile (instead of seeing one that taps to a
/// "You're not assigned" snackbar — which is the disable-by-error
/// anti-pattern this widget exists to avoid).
///
/// The whole row hides when there's nothing to show (e.g. a strict
/// read-only role) so we don't render an empty band.
class QuickActions extends ConsumerWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final visibleGroups =
        ref.watch(groupsProvider).value ?? const <Group>[];
    final openCaptureCount =
        ref.watch(openCapturesProvider).value?.length ?? 0;
    final openTaskCount = ref.watch(openTasksProvider).value?.length ?? 0;
    // Widget list — most entries are plain _Tile, but the vehicle
    // entry is a _VehicleQuickTile ConsumerWidget so it can watch
    // fleetStatusProvider in isolation. Heterogeneous list is fine
    // since the row builder just iterates Widgets.
    // The row is sorted by URGENCY: state-driven tiles (something
    // is pending) come first, then everyday actions. Off-screen on
    // a phone is a real cost — only 3–4 tiles fit at a time, so a
    // tile past index 4 is effectively hidden until the user
    // scrolls horizontally.
    final tiles = <Widget>[
      // Capture is always first — the lowest-friction entry. A
      // teacher mid-class can drop a note in two taps without
      // committing to a subject.
      _Tile(
        icon: Icons.bolt_outlined,
        label: 'Capture',
        onTap: () => context.push('/captures/new'),
      ),
      // The vehicle tile is a ConsumerWidget that watches
      // fleetStatusProvider; when the viewer has a vehicle out it
      // renders "Return {name}" with a count badge — that's pending
      // work and belongs near the front. When nothing's out, it
      // renders "Check out a vehicle" (still useful upfront for any
      // teacher about to leave for a field trip). Director-only
      // "Fleet" sticks here too — admin-side use is OK to surface
      // alongside the operational ones.
      if (viewer.canDrive || viewer.canManageSpace)
        _VehicleQuickTile(viewer: viewer),
      // The triage destinations — only surface when there's actually
      // something to triage. Count badge makes the pressure visible.
      if (openCaptureCount > 0)
        _Tile(
          icon: Icons.inbox_outlined,
          label: 'Inbox',
          badge: '$openCaptureCount',
          onTap: () => context.push('/captures'),
        ),
      if (openTaskCount > 0)
        _Tile(
          icon: Icons.check_circle_outline,
          label: 'Tasks',
          badge: '$openTaskCount',
          onTap: () => context.push('/tasks'),
        ),
      // Everyday actions — verbs the user reaches for daily. The
      // observation tiles require BOTH the cap AND at least one
      // visible group, since the form sheet can't open without a
      // groupId. Hiding the tiles for a teacher with `canObserve`
      // but no assignments avoids the tap-to-snackbar dead end.
      if (viewer.canObserve && visibleGroups.isNotEmpty)
        _Tile(
          icon: Icons.edit_note_outlined,
          label: 'New observation',
          onTap: () => startNewObservation(context, ref),
        ),
      if (viewer.canObserve && visibleGroups.isNotEmpty)
        _Tile(
          icon: Icons.menu_book_outlined,
          label: 'Observations',
          onTap: () => context.push('/observations'),
        ),
      _Tile(
        icon: Icons.poll_outlined,
        label: 'Surveys',
        onTap: () => context.push('/surveys'),
      ),
      // Admin / aggregate surfaces — later in the row since they're
      // not daily destinations. Director-only.
      if (viewer.canManageSpace)
        _Tile(
          icon: Icons.lightbulb_outline,
          label: 'Insights',
          onTap: () => context.push('/insights'),
        ),
      if (viewer.canManageSpace || viewer.canInviteStaff)
        _Tile(
          icon: Icons.groups_outlined,
          label: 'Team',
          onTap: () => context.push('/settings/team'),
        ),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick actions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

}

/// State-aware Quick Action tile for vehicles. Lives in its own
/// ConsumerWidget so fleet-log changes (which fire on every check-
/// in/out and odometer update) don't rebuild the rest of the
/// QuickActions row.
///
/// Labeling rules:
///   - viewer has a vehicle out → "Return {name}" → direct to
///     checkin form. Badge with count if multiple.
///   - viewer canDrive, nothing out → "Check out a vehicle" → list
///   - director without canDrive → "Fleet" → list
class _VehicleQuickTile extends ConsumerWidget {
  const _VehicleQuickTile({required this.viewer});

  final Viewer viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(fleetStatusProvider).value ??
        const <VehicleWithStatus>[];
    final myOut = fleet
        .where((vws) => vws.isOutBy(viewer.memberId))
        .toList(growable: false);
    if (myOut.isNotEmpty) {
      final first = myOut.first.vehicle;
      return _Tile(
        icon: Icons.assignment_turned_in_outlined,
        label: myOut.length == 1
            ? 'Return ${first.name}'
            : 'Return vehicle',
        badge: myOut.length > 1 ? '${myOut.length}' : null,
        onTap: () => unawaited(
          context.push('/vehicles/${first.id}/checkin'),
        ),
      );
    }
    if (viewer.canDrive) {
      return _Tile(
        icon: Icons.key_outlined,
        label: 'Check out a vehicle',
        onTap: () => unawaited(context.push('/vehicles')),
      );
    }
    return _Tile(
      icon: Icons.directions_bus_outlined,
      label: 'Fleet',
      onTap: () => unawaited(context.push('/vehicles')),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  /// Optional small count chip in the top-right corner (e.g. "3" for
  /// the capture inbox). Renders only when non-null.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                constraints: const BoxConstraints(minWidth: 22),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  badge!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Transient picker used when "New observation" is tapped and the
/// driver/teacher is assigned to more than one classroom. Bottom sheet
/// (not a route) because it's a one-shot quick choice — the user picks
/// a classroom and we hand off to the observation form.
class _ClassroomPickerSheet extends StatelessWidget {
  const _ClassroomPickerSheet({required this.groups});

  final List<Group> groups;

  static Future<Group?> show(
    BuildContext context, {
    required List<Group> groups,
  }) {
    return showGlassSheet<Group>(
      context: context,
      builder: (_) => _ClassroomPickerSheet(groups: groups),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GlassDragHandle(),
            Text(
              'Which classroom?',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            for (final g in groups)
              ListTile(
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text(g.name),
                subtitle: g.ageRange == null
                    ? null
                    : Text(g.ageRange!),
                onTap: () => Navigator.of(context).pop(g),
              ),
          ],
        ),
      ),
    );
  }
}
