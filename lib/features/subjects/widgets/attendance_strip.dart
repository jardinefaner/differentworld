
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AttendanceStrip extends ConsumerWidget {
  const AttendanceStrip({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync =
        ref.watch(attendanceHistoryForSubjectProvider(subjectId));

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          'Could not load attendance.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      data: (records) {
        // Build 30-day window ending today.
        final days = <DateTime>[];
        final now = DateTime.now();
        for (var i = 29; i >= 0; i--) {
          days.add(DateTime(now.year, now.month, now.day - i));
        }
        final byDate = <String, AttendanceStatus?>{};
        for (final r in records) {
          byDate[r.date] = AttendanceStatus.fromDb(r.status);
        }
        return SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final d in days) ...[
                  _AttendanceDot(
                    date: d,
                    status: byDate[_isoDate(d)],
                  ),
                  if (d != days.last) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String _isoDate(DateTime n) => dateKey(n);
}

class _AttendanceDot extends StatelessWidget {
  const _AttendanceDot({required this.date, this.status});

  final DateTime date;
  final AttendanceStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = status == null
        ? scheme.surfaceContainerHighest
        : status!.color(scheme).withValues(alpha: 0.85);
    return Expanded(
      child: Tooltip(
        message: '${DateFormat.MMMd().format(date)} '
            '· ${status?.label ?? "no record"}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
