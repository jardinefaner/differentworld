import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/routines/routine_voice.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/routines` — the **Routines** view (docs/VISION.md 2026-06-19): the
/// kid-legible read of the day. "What do we do now? / at 9?" — the room's
/// existing schedule, re-skinned with friendly icons + warm sublabels
/// (PE → "the workout for your body", brain breaks → "the workout for your
/// brain") and a "now" highlight, so a rhythm a 6-year-old can predict and
/// belong to. Reads the staff schedule live; changes nothing about it.
///
/// Per-cohort (each room has its own day); a chip selector switches cohorts.
/// Gated on `routinesEnabledProvider` at the discovery layer.
class RoutinesScreen extends ConsumerStatefulWidget {
  const RoutinesScreen({this.groupId, super.key});

  /// Optional starting cohort (from `?group=`); otherwise the first.
  final String? groupId;

  @override
  ConsumerState<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends ConsumerState<RoutinesScreen> {
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    if (groups.isEmpty) {
      return const EdgeScaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.schedule_outlined,
            title: 'No cohorts yet',
            message:
                'Create a classroom and plan its day, then the routine shows '
                'up here for the room to see.',
          ),
        ),
      );
    }
    final selected = groups.firstWhere(
      (g) => g.id == _groupId,
      orElse: () => groups.first,
    );
    final date = todayIsoLocal();
    final blocksAsync = ref.watch(
      scheduleDayForGroupProvider((groupId: selected.id, date: date)),
    );
    final activities =
        ref.watch(activitiesProvider).value ?? const <Activity>[];

    return EdgeScaffold(
      // Header + chip selector are PINNED; the day scrolls (or its loading /
      // error / empty state fills) inside the Expanded — so those states get a
      // bounded viewport instead of being nested in an outer ListView, which
      // is what crashed LoadingSlot's skeleton.
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ContentHeader(
                title: 'What do we do now?',
                subtitle: 'Today’s rhythm',
              ),
            ),
            if (groups.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final g in groups)
                      ChoiceChip(
                        label: Text(g.name),
                        selected: g.id == selected.id,
                        onSelected: (_) => setState(() => _groupId = g.id),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: blocksAsync.when(
                loading: () => const LoadingSlot(),
                error: (e, _) => ErrorState(
                  title: 'Could not load the day',
                  detail: '$e',
                  onRetry: () => ref.invalidate(
                    scheduleDayForGroupProvider((
                      groupId: selected.id,
                      date: date,
                    )),
                  ),
                ),
                data: (blocks) => _timeline(blocks, activities),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeline(List<ScheduleBlock> blocks, List<Activity> activities) {
    if (blocks.isEmpty) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      // Centered in the bounded Expanded — EmptyState would over-fill here.
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 48,
                color: scheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Text(
                'Nothing planned yet today',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'When staff plan the day, it appears here for the room.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final sorted = [...blocks]..sort((a, b) => a.startAt.compareTo(b.startAt));
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        for (final block in sorted)
          _RoutineRow(
            block: block,
            label: _labelFor(block, activities),
            now: now,
          ),
      ],
    );
  }

  String _labelFor(ScheduleBlock block, List<Activity> activities) {
    final title = block.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    if (block.activityId != null) {
      for (final a in activities) {
        if (a.id == block.activityId) return a.name;
      }
    }
    return 'Activity';
  }
}

/// One block in the kid-facing day — time, friendly icon, the activity, and a
/// warm sublabel. The block happening now is highlighted; finished blocks dim.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    required this.block,
    required this.label,
    required this.now,
  });

  final ScheduleBlock block;
  final String label;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = DateTime.tryParse(block.startAt);
    final end = DateTime.tryParse(block.endAt);
    final isNow =
        start != null &&
        end != null &&
        !now.isBefore(start) &&
        now.isBefore(end);
    final isPast = end != null && !now.isBefore(end);
    final timeStr = start != null ? timeOfDay(start.toLocal()) : '';
    final sublabel = RoutineVoice.sublabelFor(label);
    final icon = RoutineVoice.iconFor(label);

    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isNow ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: isNow
            ? const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
            : BorderRadius.circular(16),
        border: isNow
            ? Border(left: BorderSide(color: scheme.primary, width: 4))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              timeStr,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isNow ? scheme.onPrimaryContainer : scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            icon,
            size: 22,
            color: isNow ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isNow ? scheme.onPrimaryContainer : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isNow) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'now',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (sublabel != null)
                  Text(
                    sublabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isNow
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // Finished blocks fade back so "now" + what's next read first.
    return Opacity(opacity: isPast && !isNow ? 0.45 : 1, child: row);
  }
}
