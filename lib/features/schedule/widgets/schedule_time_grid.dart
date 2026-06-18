import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/curricula/photo_curriculum.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The **time-aligned schedule grid** (docs/GRID.md — the schedule consumer):
/// cohorts as rows, a shared time axis as columns, blocks positioned + spanning
/// by their start/end. Where the default wide view (cohort columns)
/// times each cohort independently, this aligns everything to one axis so
/// "who's outside at 4:00" is a single horizontal read. Opt-in via
/// `scheduleTimeGridProvider`; phones keep the per-cohort tabs.
///
/// Read-rich, edit-on-tap: every block carries its live signals (now, field
/// trip, break, shared-room conflict, curriculum link) and taps straight into
/// the full block editor — no richness lost vs the agenda rows.
class ScheduleTimeGrid extends ConsumerWidget {
  const ScheduleTimeGrid({
    required this.groups,
    required this.date,
    super.key,
  });

  final List<Group> groups;

  /// ISO `YYYY-MM-DD` for the viewed day.
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(scheduleDayProvider(date));
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];

    return blocksAsync.when(
      loading: () => const LoadingSlot(),
      error: (err, _) => ErrorState(
        title: 'Could not load the schedule',
        detail: '$err',
        onRetry: () => ref.invalidate(scheduleDayProvider(date)),
      ),
      data: (blocks) {
        if (blocks.isEmpty) {
          return const EmptyState(
            icon: Icons.view_timeline_outlined,
            title: 'Nothing scheduled yet',
            message:
                'Add a block (or apply a day template) and it appears on the '
                'timeline for every cohort at once.',
          );
        }
        return _Grid(
          groups: groups,
          date: date,
          blocks: blocks,
          activities: activities,
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.groups,
    required this.date,
    required this.blocks,
    required this.activities,
  });

  final List<Group> groups;
  final String date;
  final List<ScheduleBlock> blocks;
  final List<Activity> activities;

  static const _labelW = 108.0;
  static const _rowH = 62.0;
  static const _headerH = 26.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // ── window: floor the earliest start / ceil the latest end to :00/:30.
    DateTime? lo;
    DateTime? hi;
    for (final b in blocks) {
      final s = DateTime.tryParse(b.startAt)?.toLocal();
      final e = DateTime.tryParse(b.endAt)?.toLocal();
      if (s == null || e == null) continue;
      if (lo == null || s.isBefore(lo)) lo = s;
      if (hi == null || e.isAfter(hi)) hi = e;
    }
    if (lo == null || hi == null) {
      return const EmptyState(
        icon: Icons.view_timeline_outlined,
        title: 'Nothing scheduled yet',
        message: 'Add a block to see it on the timeline.',
      );
    }
    final winStart = _floor30(lo);
    final winEnd = _ceil30(hi);
    final windowMin = winEnd.difference(winStart).inMinutes.clamp(30, 24 * 60);

    // Blocks per cohort + the day's shared-room conflicts (computed once).
    final byGroup = <String, List<ScheduleBlock>>{};
    for (final b in blocks) {
      (byGroup[b.groupId] ??= <ScheduleBlock>[]).add(b);
    }
    final conflicted = _conflictedBlockIds(blocks, activities);

    final now = DateTime.now();
    final isToday = date == todayIsoLocal();
    final nowInWindow =
        isToday && !now.isBefore(winStart) && now.isBefore(winEnd);

    // Hourly ticks across the window.
    final ticks = <DateTime>[];
    var t = DateTime(
      winStart.year,
      winStart.month,
      winStart.day,
      winStart.hour,
    );
    if (t.isBefore(winStart)) t = t.add(const Duration(hours: 1));
    while (!t.isAfter(winEnd)) {
      ticks.add(t);
      t = t.add(const Duration(hours: 1));
    }

    return LayoutBuilder(
      builder: (context, c) {
        final timeW = (c.maxWidth - _labelW).clamp(120.0, double.infinity);
        final pxPerMin = timeW / windowMin;
        final rowsH = groups.length * _rowH;
        final gridH = _headerH + rowsH;

        double xFor(DateTime when) =>
            _labelW + when.difference(winStart).inMinutes * pxPerMin;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          child: SizedBox(
            height: gridH,
            width: c.maxWidth,
            child: Stack(
              children: [
                // ── faint hour gridlines behind everything ──
                for (final tick in ticks)
                  Positioned(
                    left: xFor(tick),
                    top: _headerH,
                    height: rowsH,
                    child: Container(
                      width: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                // ── header ticks + cohort rows ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _headerH,
                      child: Stack(
                        children: [
                          for (final tick in ticks)
                            Positioned(
                              left: xFor(tick) + 4,
                              top: 4,
                              child: Text(
                                _fmtHour(tick),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final g in groups)
                      _CohortRow(
                        key: ValueKey('tg-row-${g.id}'),
                        group: g,
                        date: date,
                        blocks: byGroup[g.id] ?? const <ScheduleBlock>[],
                        activities: activities,
                        conflicted: conflicted,
                        winStart: winStart,
                        pxPerMin: pxPerMin,
                        timeW: timeW,
                        rowH: _rowH,
                        labelW: _labelW,
                        now: isToday ? now : null,
                      ),
                  ],
                ),
                // ── the now-line on top ──
                if (nowInWindow)
                  Positioned(
                    left: xFor(now),
                    top: _headerH - 4,
                    height: rowsH + 4,
                    child: IgnorePointer(
                      child: Container(width: 2, color: scheme.primary),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static DateTime _floor30(DateTime d) =>
      DateTime(d.year, d.month, d.day, d.hour, d.minute < 30 ? 0 : 30);

  static DateTime _ceil30(DateTime d) {
    if (d.minute == 0) return DateTime(d.year, d.month, d.day, d.hour);
    if (d.minute <= 30) return DateTime(d.year, d.month, d.day, d.hour, 30);
    return DateTime(
      d.year,
      d.month,
      d.day,
      d.hour,
    ).add(const Duration(hours: 1));
  }

  static String _fmtHour(DateTime d) => DateFormat('h a').format(d);

  /// Block ids that share an effective location (override OR the activity's
  /// default) with a DIFFERENT cohort's block at an overlapping time. Mirrors
  /// the agenda's shared-room warning.
  static Set<String> _conflictedBlockIds(
    List<ScheduleBlock> blocks,
    List<Activity> activities,
  ) {
    // Precompute activity → default location so each block's effective
    // location is an O(1) lookup, not a linear scan per cross-group pair.
    final activityLoc = {for (final a in activities) a.id: a.defaultLocationId};
    String? locOf(ScheduleBlock b) =>
        b.locationOverrideId ??
        (b.activityId == null ? null : activityLoc[b.activityId]);

    final out = <String>{};
    for (var i = 0; i < blocks.length; i++) {
      final a = blocks[i];
      final aLoc = locOf(a);
      if (aLoc == null) continue;
      final aStart = DateTime.tryParse(a.startAt);
      final aEnd = DateTime.tryParse(a.endAt);
      if (aStart == null || aEnd == null) continue;
      for (var j = i + 1; j < blocks.length; j++) {
        final b = blocks[j];
        if (b.groupId == a.groupId) continue;
        if (locOf(b) != aLoc) continue;
        final bStart = DateTime.tryParse(b.startAt);
        final bEnd = DateTime.tryParse(b.endAt);
        if (bStart == null || bEnd == null) continue;
        if (aStart.isBefore(bEnd) && bStart.isBefore(aEnd)) {
          out
            ..add(a.id)
            ..add(b.id);
        }
      }
    }
    return out;
  }
}

class _CohortRow extends StatelessWidget {
  const _CohortRow({
    required this.group,
    required this.date,
    required this.blocks,
    required this.activities,
    required this.conflicted,
    required this.winStart,
    required this.pxPerMin,
    required this.timeW,
    required this.rowH,
    required this.labelW,
    required this.now,
    super.key,
  });

  final Group group;
  final String date;
  final List<ScheduleBlock> blocks;
  final List<Activity> activities;
  final Set<String> conflicted;
  final DateTime winStart;
  final double pxPerMin;
  final double timeW;
  final double rowH;
  final double labelW;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: rowH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: labelW,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (group.ageRange != null)
                    Text(
                      group.ageRange!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: timeW,
            child: Stack(
              children: [
                for (final b in blocks) _positioned(context, b),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _positioned(BuildContext context, ScheduleBlock b) {
    final start = DateTime.tryParse(b.startAt)?.toLocal();
    final end = DateTime.tryParse(b.endAt)?.toLocal();
    if (start == null || end == null) return const SizedBox.shrink();
    final left = start.difference(winStart).inMinutes * pxPerMin;
    final width = (end.difference(start).inMinutes * pxPerMin - 3).clamp(
      26.0,
      timeW,
    );
    final isNow = now != null && !start.isAfter(now!) && end.isAfter(now!);
    return Positioned(
      key: ValueKey('tg-blk-${b.id}'),
      left: left.clamp(0.0, timeW),
      width: width,
      top: 4,
      bottom: 4,
      child: _GridBlockCell(
        block: b,
        title: _titleFor(b),
        isNow: isNow,
        hasConflict: conflicted.contains(b.id),
        timeLabel: '${_t(start)}–${_t(end)}',
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          unawaited(
            context.push<void>(
              '/schedule/block',
              extra: (
                groupId: b.groupId,
                defaultStart: start,
                existing: b,
                prefillCurriculumSlug: null,
              ),
            ),
          );
        },
      ),
    );
  }

  String _titleFor(ScheduleBlock b) {
    final t = b.title?.trim() ?? '';
    if (t.isNotEmpty) return t;
    final slug = b.curriculumSessionSlug;
    if (slug != null) {
      final s = findSessionBySlug(slug);
      if (s != null) return s.title;
    }
    if (b.activityId != null) {
      final a = activities.where((a) => a.id == b.activityId).firstOrNull;
      if (a != null) return a.name;
    }
    if (b.kind == BlockKind.breakBlock) return 'Break';
    if (b.kind == BlockKind.fieldTrip) return 'Field trip';
    return 'Untitled block';
  }

  static String _t(DateTime d) => DateFormat.jm().format(d);
}

/// One positioned block in the time grid — themed by its state (now / field /
/// break / on-site), carrying the live signals and tapping into the editor.
class _GridBlockCell extends StatelessWidget {
  const _GridBlockCell({
    required this.block,
    required this.title,
    required this.isNow,
    required this.hasConflict,
    required this.timeLabel,
    required this.onTap,
  });

  final ScheduleBlock block;
  final String title;
  final bool isNow;
  final bool hasConflict;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isField = block.kind == BlockKind.fieldTrip;
    final isBreak = block.kind == BlockKind.breakBlock;
    final isSkipped =
        block.status == BlockStatus.skipped ||
        block.status == BlockStatus.cancelled;
    final isCurriculum = block.curriculumSessionSlug != null;

    final (Color bg, Color fg) = isNow
        ? (scheme.primaryContainer, scheme.onPrimaryContainer)
        : isField
        ? (scheme.tertiaryContainer, scheme.onTertiaryContainer)
        : isBreak
        ? (scheme.surfaceContainerHighest, scheme.onSurfaceVariant)
        : (scheme.secondaryContainer, scheme.onSecondaryContainer);

    final icon = isField
        ? Icons.directions_bus_outlined
        : isBreak
        ? Icons.local_cafe_outlined
        : isCurriculum
        ? Icons.photo_camera_outlined
        : Icons.local_activity_outlined;

    return Opacity(
      opacity: isSkipped ? 0.55 : 1,
      child: Semantics(
        button: true,
        label: '$title, $timeLabel${hasConflict ? ', shared room' : ''}',
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 13, color: fg),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasConflict)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: scheme.tertiary,
                          ),
                        ),
                      if (isNow)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    timeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: fg.withValues(alpha: 0.78),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
