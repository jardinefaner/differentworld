import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/groups/room_skin_background.dart';
import 'package:differentworld/features/groups/room_skins.dart';
import 'package:differentworld/features/groups/widgets/group_chip_row.dart';
import 'package:differentworld/features/routines/routine_voice.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the day's routine steps re-lay as a
    // dense 2-up grid (over the SAME schedule provider) instead of the
    // single-column timeline; off keeps the existing list. The pinned header +
    // cohort chips, the RoomSkinBackground, and the bounded-viewport
    // loading/error/empty states are untouched either way.
    final bento = bentoEnabled(ref, perScreen: null);

    final skin = roomSkinForGroup(selected);
    return EdgeScaffold(
      // The room's theme, decaled subtly behind the Calm content.
      background: skin == null
          ? null
          : RoomSkinBackground(skin: skin, decal: true, animate: true),
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
            GroupChipRow(
              groups: groups,
              selectedId: selected.id,
              onSelected: (id) => setState(() => _groupId = id),
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
                data: (blocks) => _timeline(blocks, activities, bento: bento),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeline(
    List<ScheduleBlock> blocks,
    List<Activity> activities, {
    required bool bento,
  }) {
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
    if (bento) {
      // SAME steps, sorted the same way, re-laid as a dense grid that's 2-up
      // on a phone (≈260dp cells), more across wider screens — a day at a
      // glance instead of one long scroll. `mainAxisExtent` bounds each cell
      // so the row's intrinsic-height card sits in a fixed tile. Stable keys
      // per block (the Wrap/grid-children-need-keys rule).
      // The cell grows with the user's text-size setting so the label + warm
      // sublabel don't clip at 150% scale (the fixed-aspect trap; see
      // present_hub).
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          // Tall enough for time + icon + label + a 2-line warm sublabel,
          // scaling up with the text-size setting.
          mainAxisExtent: 64 + 40 * textScale,
        ),
        itemCount: sorted.length,
        itemBuilder: (context, i) {
          final block = sorted[i];
          return _RoutineRow(
            key: ValueKey('routine-${block.id}'),
            block: block,
            label: _labelFor(block, activities),
            now: now,
          );
        },
      );
    }
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
    super.key,
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
