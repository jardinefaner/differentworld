import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/rooms/room_load_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What this room is doing today, and who is on it (docs/ROOMS.md).
///
/// The room used to be a roster: you could reach attendance, observations
/// and the children, but not "what is Sparrows doing at 3pm" — that lived
/// only on the program-wide schedule, behind cohort tabs. A room that
/// cannot show its own day is a list of names, not a place.
///
/// Deliberately a STRIP, not a second schedule: the next two blocks and the
/// adults assigned. Anything more and it becomes a screen you have to read
/// rather than glance at.
class RoomTodayStrip extends ConsumerWidget {
  const RoomTodayStrip({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocks =
        ref
            .watch(
              scheduleDayForGroupProvider((
                groupId: groupId,
                date: todayKey(),
              )),
            )
            .value ??
        const <ScheduleBlock>[];
    final staff = ref.watch(staffOnGroupProvider(groupId)).value ?? const [];

    final now = DateTime.now();
    // What is still ahead — a block that finished an hour ago is history,
    // and history is not what you glance at a room for.
    final upcoming = [
      for (final b in blocks)
        if ((DateTime.tryParse(b.endAt)?.toLocal() ?? now).isAfter(now)) b,
    ];

    if (blocks.isEmpty && staff.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _summary(blocks.length, upcoming.length, staff.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (blocks.isNotEmpty)
                TextButton(
                  onPressed: () => unawaited(context.push('/schedule')),
                  child: const Text('Whole day'),
                ),
            ],
          ),
          for (final b in upcoming.take(2))
            _BlockRow(block: b, groupId: groupId),
        ],
      ),
    );
  }

  String _summary(int total, int ahead, int staffCount) {
    final adults = staffCount == 1
        ? '1 adult on this room'
        : '$staffCount adults on this room';
    if (total == 0) return 'Nothing scheduled today · $adults';
    if (ahead == 0) return 'Day finished · $adults';
    return '$ahead of $total left today · $adults';
  }
}

class _BlockRow extends ConsumerWidget {
  const _BlockRow({required this.block, required this.groupId});

  final ScheduleBlock block;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final start = DateTime.tryParse(block.startAt)?.toLocal();
    return InkWell(
      onTap: () => unawaited(context.push('/schedule')),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(
                start == null ? '' : timeOfDay(start),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                block.title?.trim().isNotEmpty == true
                    ? block.title!
                    : _kindLabel(block.kind),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _kindLabel(String kind) => switch (kind) {
    'field_trip' => 'Field trip',
    'break' => 'Break',
    'closed' => 'Closed',
    _ => 'Activity',
  };
}
