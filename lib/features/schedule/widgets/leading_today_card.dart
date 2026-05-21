import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/widgets/pre_block_brief_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Pat persona — when the viewer is leading a block only because
/// they're covering for someone, surface "Covering for {name}" so
/// they walk into the block knowing whose plan they're picking up.
class _CoveringBadge extends ConsumerWidget {
  const _CoveringBadge({required this.originalLeadId, required this.color});

  final String originalLeadId;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final originalAsync = ref.watch(memberByIdProvider(originalLeadId));
    final name = originalAsync.value?.displayName;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            name == null ? 'Covering' : 'Covering for $name',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Today I'm leading…" — surfaces the schedule blocks where the
/// signed-in member is the lead. Renders nothing when the member has
/// no blocks for today (i.e., they're not assigned to lead anything).
///
/// Lives on the Today screen for any staff member; useful for both
/// regular teachers ("what's my room doing next") and specialists
/// ("when is archery, who am I with").
///
/// Tapping a row jumps into the schedule day so the user can see the
/// full context.
class LeadingTodayCard extends ConsumerWidget {
  const LeadingTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberId = ref.watch(currentMemberProvider).value?.id;
    if (memberId == null) return const SizedBox.shrink();

    final blocksAsync = ref.watch(
      scheduleDayForLeadProvider(
        (memberId: memberId, date: todayIsoLocal()),
      ),
    );
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final locations =
        ref.watch(locationsProvider).value ?? const <Location>[];

    return blocksAsync.maybeWhen(
      data: (blocks) {
        if (blocks.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final now = DateTime.now();

        return Material(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/schedule'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_pin_outlined,
                        color: scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          blocks.length == 1
                              ? "You're leading 1 block today"
                              : "You're leading ${blocks.length} blocks today",
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: scheme.onTertiaryContainer
                            .withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final b in blocks)
                    _LeadingRow(
                      block: b,
                      activities: activities,
                      locations: locations,
                      now: now,
                    ),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _LeadingRow extends ConsumerWidget {
  const _LeadingRow({
    required this.block,
    required this.activities,
    required this.locations,
    required this.now,
  });

  final ScheduleBlock block;
  final List<Activity> activities;
  final List<Location> locations;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = DateTime.parse(block.startAt).toLocal();
    final end = DateTime.parse(block.endAt).toLocal();
    final activity = block.activityId == null
        ? null
        : activities.where((a) => a.id == block.activityId).firstOrNull;
    final loc = block.locationOverrideId != null
        ? locations
            .where((l) => l.id == block.locationOverrideId)
            .firstOrNull
        : activity?.defaultLocationId == null
            ? null
            : locations
                .where((l) => l.id == activity!.defaultLocationId)
                .firstOrNull;

    final isCurrent = !now.isBefore(start) && now.isBefore(end);
    final isPast = now.isAfter(end);

    final fg = scheme.onTertiaryContainer
        .withValues(alpha: isPast ? 0.55 : 1.0);
    final timeFg = scheme.onTertiaryContainer
        .withValues(alpha: isPast ? 0.5 : 0.85);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        // Tap a row → pre-block brief sheet. Specialists use this 30
        // seconds before a block to remind themselves of allergies,
        // supplies, and who's in the group.
        borderRadius: BorderRadius.circular(6),
        onTap: () => PreBlockBriefSheet.show(context, block.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: Text(
                  '${_fmt(start)}–${_fmt(end)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: timeFg,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    decoration: isPast ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
          if (isCurrent) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: scheme.onTertiaryContainer.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'NOW',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontSize: 9,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc == null
                      ? (activity?.name ??
                          (block.kind == 'break' ? 'Break' : '—'))
                      : '${activity?.name ?? "—"} · ${loc.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    decoration: isPast ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Pat persona — when the viewer is on this block only
                // because they're covering, label the row so they
                // know they're picking up someone else's plan.
                if (block.leadSubstituteMemberId != null &&
                    block.leadMemberId != null &&
                    block.leadMemberId != block.leadSubstituteMemberId)
                  _CoveringBadge(
                    originalLeadId: block.leadMemberId!,
                    color: timeFg,
                  ),
              ],
            ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime when) {
    final h = when.hour.toString().padLeft(2, '0');
    final m = when.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
