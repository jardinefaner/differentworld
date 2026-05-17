import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:flutter/material.dart';

/// Modal bottom sheet listing all five attendance statuses. Returns the
/// selected status (or null if dismissed).
class StatusPickerSheet extends StatelessWidget {
  const StatusPickerSheet({
    required this.studentName,
    this.currentStatus,
    super.key,
  });

  final String studentName;
  final AttendanceStatus? currentStatus;

  static Future<AttendanceStatus?> show(
    BuildContext context, {
    required String studentName,
    AttendanceStatus? currentStatus,
  }) {
    return showModalBottomSheet<AttendanceStatus>(
      context: context,
      useSafeArea: true,
      builder: (_) => StatusPickerSheet(
        studentName: studentName,
        currentStatus: currentStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                studentName,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            ...AttendanceStatus.values.map((status) {
              final selected = status == currentStatus;
              return ListTile(
                leading: Icon(
                  status.icon,
                  color: status.color(theme.colorScheme),
                ),
                title: Text(status.label),
                trailing: selected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(status),
              );
            }),
          ],
        ),
      ),
    );
  }
}
