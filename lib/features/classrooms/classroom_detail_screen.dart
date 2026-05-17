import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/classrooms/widgets/classroom_form_sheet.dart';
import 'package:differentworld/features/roster/students_providers.dart';
import 'package:differentworld/features/roster/widgets/student_form_sheet.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClassroomDetailScreen extends ConsumerWidget {
  const ClassroomDetailScreen({required this.classroomId, super.key});

  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classroomAsync = ref.watch(_classroomProvider(classroomId));
    final studentsAsync = ref.watch(classroomStudentsProvider(classroomId));

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
        title: classroomAsync.when(
          loading: () => const Text('Classroom'),
          error: (_, _) => const Text('Classroom'),
          data: (c) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c?.name ?? 'Classroom'),
              if (c?.ageRange != null)
                Text(
                  c!.ageRange!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Take attendance',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () =>
                context.go('/classrooms/$classroomId/attendance'),
          ),
          if (classroomAsync.value != null)
            IconButton(
              tooltip: 'Edit classroom',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => ClassroomFormSheet.show(
                context,
                classroom: classroomAsync.value,
              ),
            ),
          const SyncStatusIndicator(),
        ],
      ),
      body: SafeArea(
        child: studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load students',
            message: err.toString(),
          ),
          data: (students) {
            if (students.isEmpty) {
              return EmptyState(
                icon: Icons.child_care_outlined,
                title: 'No students yet',
                message: 'Add your first student to start taking attendance '
                    'and logging observations.',
                action: FilledButton.icon(
                  onPressed: () => StudentFormSheet.show(
                    context,
                    classroomId: classroomId,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add student'),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: students.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _StudentTile(student: students[i]),
            );
          },
        ),
      ),
      floatingActionButton: studentsAsync.maybeWhen(
        data: (s) => s.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => StudentFormSheet.show(
                  context,
                  classroomId: classroomId,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Student'),
              ),
        orElse: () => null,
      ),
    );
  }
}

/// Live single-classroom stream. Re-fetched whenever the classroom row
/// changes (e.g. user edits the name).
// ignore: specify_nonobvious_property_types
final _classroomProvider = StreamProvider.family<Classroom?, String>(
  (ref, classroomId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchClassroom(classroomId);
  },
);

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(student.firstName, student.lastName);
    final ageLine = _ageLine(student.dob);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Text(initials),
      ),
      title: Text('${student.firstName} ${student.lastName}'),
      subtitle: ageLine == null ? null : Text(ageLine),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => StudentFormSheet.show(
        context,
        classroomId: student.classroomId ?? '',
        student: student,
      ),
    );
  }

  static String _initials(String first, String last) {
    String firstChar(String s) {
      final t = s.trim();
      return t.isEmpty ? '' : t.substring(0, 1).toUpperCase();
    }

    final f = firstChar(first);
    final l = firstChar(last);
    final joined = '$f$l';
    return joined.isEmpty ? '?' : joined;
  }

  static String? _ageLine(String? dobIso) {
    if (dobIso == null || dobIso.isEmpty) return null;
    final dob = DateTime.tryParse(dobIso);
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    var months = now.month - dob.month;
    if (now.day < dob.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years <= 0) return '$months mo';
    if (months == 0) return '$years yr';
    return '$years yr $months mo';
  }
}
