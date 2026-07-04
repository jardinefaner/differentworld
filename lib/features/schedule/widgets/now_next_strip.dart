import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/family/family_providers.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Compact "now / next" preview for a single cohort. Surfaces:
///
///   - The block happening right now (if any), with activity name,
///     location, and time-remaining countdown.
///   - The next block coming up (if any).
///
/// Renders nothing (a 0-height SizedBox) when the cohort has no
/// blocks today at all — caller decides whether to hide the
/// section entirely or show their own empty state above.
///
/// Used by:
///   - Family Today's per-child card (one cohort = the kid's room).
///   - Staff Today's per-cohort card.
class NowNextStrip extends ConsumerWidget {
  const NowNextStrip({
    required this.groupId,
    this.compact = false,
    super.key,
  });

  final String groupId;

  /// Compact = single-line "Now: art (10:00–11:00, art barn)" for
  /// dense list rows. Default is the two-line block-card form.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = todayIsoLocal();
    // Wave 160: viewer-aware data source. Staff devices have
    // schedule_blocks in local Drift via the by_space sync; guardian
    // devices don't, so they fetch via the PostgREST fallback (same
    // pattern as attendance / entries / attachments).
    final viewer = ref.watch(viewerProvider);
    final AsyncValue<List<ScheduleBlock>> blocksAsync;
    if (viewer is GuardianViewer) {
      blocksAsync = ref.watch(
        familyScheduleForGroupProvider((groupId: groupId, dateIso: date)),
      );
    } else {
      blocksAsync = ref.watch(
        scheduleDayForGroupProvider((groupId: groupId, date: date)),
      );
    }
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];

    return blocksAsync.maybeWhen(
      data: (blocks) {
        if (blocks.isEmpty) return const SizedBox.shrink();
        final now = DateTime.now();
        ScheduleBlock? current;
        ScheduleBlock? next;
        for (final b in blocks) {
          final s = DateTime.parse(b.startAt).toLocal();
          final e = DateTime.parse(b.endAt).toLocal();
          if (!now.isBefore(s) && now.isBefore(e)) {
            current = b;
            continue;
          }
          if (s.isAfter(now) && next == null) {
            next = b;
          }
        }
        if (current == null && next == null) {
          // All today's blocks are in the past — surface the LAST one
          // as a faded "wrapped up" marker so the card doesn't go
          // empty after the camp day ends.
          final past = blocks.last;
          return _BlockRow(
            label: 'Today',
            block: past,
            activities: activities,
            locations: locations,
            tone: _Tone.past,
            compact: compact,
          );
        }

        if (compact) {
          // Compact form picks ONE block to surface — prefer the
          // current one, fall back to the next. Saves vertical real
          // estate on the family child card.
          final pick = current ?? next!;
          return _BlockRow(
            label: current != null ? 'Now' : 'Next',
            block: pick,
            activities: activities,
            locations: locations,
            tone: current != null ? _Tone.now : _Tone.next,
            compact: true,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current != null)
              _BlockRow(
                label: 'Now',
                block: current,
                activities: activities,
                locations: locations,
                tone: _Tone.now,
                compact: false,
              ),
            if (current != null && next != null) const SizedBox(height: 8),
            if (next != null)
              _BlockRow(
                label: 'Next',
                block: next,
                activities: activities,
                locations: locations,
                tone: _Tone.next,
                compact: false,
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

enum _Tone { now, next, past }

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.label,
    required this.block,
    required this.activities,
    required this.locations,
    required this.tone,
    required this.compact,
  });

  final String label;
  final ScheduleBlock block;
  final List<Activity> activities;
  final List<Location> locations;
  final _Tone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activity = block.activityId == null
        ? null
        : activities.where((a) => a.id == block.activityId).firstOrNull;
    final loc = block.locationOverrideId == null
        ? activity?.defaultLocationId == null
              ? null
              : locations
                    .where((l) => l.id == activity!.defaultLocationId)
                    .firstOrNull
        : locations.where((l) => l.id == block.locationOverrideId).firstOrNull;
    final start = DateTime.parse(block.startAt).toLocal();
    final end = DateTime.parse(block.endAt).toLocal();
    final timeLabel = '${_fmt(start)}–${_fmt(end)}';
    final title =
        activity?.name ??
        (block.kind == BlockKind.breakBlock ? 'Break' : block.notes ?? '—');

    final (container, onContainer) = switch (tone) {
      _Tone.now => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _Tone.next => (scheme.surfaceContainerHighest, scheme.onSurface),
      _Tone.past => (
        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        scheme.onSurfaceVariant,
      ),
    };

    final labelChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: onContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: onContainer,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );

    if (compact) {
      return Material(
        color: container,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/schedule'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
            child: Row(
              children: [
                labelChip,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc == null ? title : '$title · ${loc.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  timeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onContainer.withValues(alpha: 0.85),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: container,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/schedule'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              labelChip,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onContainer,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      loc == null ? timeLabel : '$timeLabel · ${loc.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onContainer.withValues(alpha: 0.85),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: onContainer.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime when) => timeOfDay(when);
}
