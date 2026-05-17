import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/attendance/widgets/status_picker_sheet.dart';
import 'package:differentworld/features/roster/students_providers.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Daily attendance for a single classroom. Per-student status, optimistic
/// writes, date scrubber, "Mark all present" shortcut.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({
    required this.classroomId,
    this.initialDate,
    super.key,
  });

  final String classroomId;
  final DateTime? initialDate;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = widget.initialDate ?? DateTime(now.year, now.month, now.day);
  }

  String get _isoDate {
    final y = _date.year.toString().padLeft(4, '0');
    final m = _date.month.toString().padLeft(2, '0');
    final d = _date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _shiftDay(int days) {
    setState(() {
      _date = _date.add(Duration(days: days));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  String _dateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = _date.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    if (diff == 1) return 'Tomorrow';
    return _isoDate;
  }

  @override
  Widget build(BuildContext context) {
    final classroomAsync = ref.watch(_classroomDetailProvider(widget.classroomId));
    final studentsAsync = ref.watch(
      classroomStudentsProvider(widget.classroomId),
    );
    final recordsAsync = ref.watch(
      attendanceForDayProvider(
        (classroomId: widget.classroomId, date: _isoDate),
      ),
    );

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance'),
            Text(
              classroomAsync.value?.name ?? '',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: const [SyncStatusIndicator()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _DateScrubber(
              label: _dateLabel(),
              onPrev: () => _shiftDay(-1),
              onNext: () => _shiftDay(1),
              onTapLabel: _pickDate,
            ),
            const Divider(height: 1),
            Expanded(
              child: studentsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => const EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load students',
                ),
                data: (students) {
                  if (students.isEmpty) {
                    return const EmptyState(
                      icon: Icons.child_care_outlined,
                      title: 'No students in this classroom',
                      message:
                          'Add students first, then come back to take attendance.',
                    );
                  }
                  return recordsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => const EmptyState(
                      icon: Icons.error_outline,
                      title: 'Could not load attendance',
                    ),
                    data: (records) => _AttendanceList(
                      classroomId: widget.classroomId,
                      date: _isoDate,
                      students: students,
                      records: records,
                    ),
                  );
                },
              ),
            ),
            _SummaryBar(
              students: studentsAsync.value,
              records: recordsAsync.value,
            ),
          ],
        ),
      ),
      floatingActionButton: studentsAsync.maybeWhen(
        data: (students) => students.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () async {
                  final actions = ref.read(attendanceActionsProvider);
                  final records = recordsAsync.value ?? const [];
                  await actions.markAllPresent(
                    classroomId: widget.classroomId,
                    date: _isoDate,
                    studentIds: students.map((s) => s.id).toList(),
                    alreadyRecordedStudentIds:
                        records.map((r) => r.studentId).toList(),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark all present'),
              ),
        orElse: () => null,
      ),
    );
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _classroomDetailProvider = StreamProvider.family<Classroom?, String>(
  (ref, classroomId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchClassroom(classroomId);
  },
);

class _DateScrubber extends StatelessWidget {
  const _DateScrubber({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onTapLabel,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            tooltip: 'Previous day',
          ),
          Expanded(
            child: TextButton(
              onPressed: onTapLabel,
              child: Text(label, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}

class _AttendanceList extends ConsumerWidget {
  const _AttendanceList({
    required this.classroomId,
    required this.date,
    required this.students,
    required this.records,
  });

  final String classroomId;
  final String date;
  final List<Student> students;
  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Map student id → current status for fast row lookup.
    final byStudent = <String, AttendanceStatus>{};
    for (final r in records) {
      final s = AttendanceStatus.fromDb(r.status);
      if (s != null) byStudent[r.studentId] = s;
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: students.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final student = students[i];
        return _AttendanceRow(
          student: student,
          status: byStudent[student.id],
          onChangeStatus: (next) async {
            await ref.read(attendanceActionsProvider).setStatus(
                  classroomId: classroomId,
                  studentId: student.id,
                  date: date,
                  status: next,
                );
          },
        );
      },
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.student,
    required this.status,
    required this.onChangeStatus,
  });

  final Student student;
  final AttendanceStatus? status;
  final Future<void> Function(AttendanceStatus) onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = _initials(student.firstName, student.lastName);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(initials),
      ),
      title: Text('${student.firstName} ${student.lastName}'),
      trailing: _StatusChip(status: status),
      onTap: () async {
        final picked = await StatusPickerSheet.show(
          context,
          studentName: '${student.firstName} ${student.lastName}',
          currentStatus: status,
        );
        if (picked != null) {
          await onChangeStatus(picked);
        }
      },
    );
  }

  static String _initials(String first, String last) {
    String firstChar(String s) {
      final t = s.trim();
      return t.isEmpty ? '' : t.substring(0, 1).toUpperCase();
    }

    final joined = '${firstChar(first)}${firstChar(last)}';
    return joined.isEmpty ? '?' : joined;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AttendanceStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (status == null) {
      return Chip(
        label: const Text('Mark'),
        avatar: const Icon(Icons.add, size: 16),
        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      );
    }
    final color = status!.color(theme.colorScheme);
    return Chip(
      avatar: Icon(status!.icon, size: 16, color: color),
      label: Text(status!.label, style: TextStyle(color: color)),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.students, required this.records});

  final List<Student>? students;
  final List<AttendanceRecord>? records;

  @override
  Widget build(BuildContext context) {
    if (students == null || records == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final counts = <AttendanceStatus, int>{};
    for (final r in records!) {
      final s = AttendanceStatus.fromDb(r.status);
      if (s != null) counts[s] = (counts[s] ?? 0) + 1;
    }
    final marked = counts.values.fold<int>(0, (a, b) => a + b);
    final unmarked = students!.length - marked;

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ...AttendanceStatus.values
                  .where((s) => (counts[s] ?? 0) > 0)
                  .map((s) {
                final color = s.color(theme.colorScheme);
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Icon(s.icon, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        '${counts[s]}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Spacer(),
              if (unmarked > 0)
                Text(
                  '$unmarked unmarked',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
