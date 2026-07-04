import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayStatusCard extends ConsumerWidget {
  const TodayStatusCard({
    required this.subjectId,
    required this.groupId,
    super.key,
  });

  final String subjectId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isoToday = _isoDate(DateTime.now());
    final recordsAsync = ref.watch(
      attendanceForDayProvider((groupId: groupId, date: isoToday)),
    );
    AttendanceRecord? mine;
    final all = recordsAsync.value ?? const <AttendanceRecord>[];
    for (final r in all) {
      if (r.subjectId == subjectId) {
        mine = r;
        break;
      }
    }
    final status = mine == null ? null : AttendanceStatus.fromDb(mine.status);
    final scheme = theme.colorScheme;
    final color = status?.color(scheme) ?? scheme.outline;
    final label = status?.label ?? 'Not yet checked in';
    final icon = status?.icon ?? Icons.help_outline;

    final shouldAlert =
        status == AttendanceStatus.late || status == AttendanceStatus.absent;

    return Card(
      color: shouldAlert
          ? color.withValues(alpha: 0.10)
          : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _isoDate(DateTime n) => dateKey(n);
}
