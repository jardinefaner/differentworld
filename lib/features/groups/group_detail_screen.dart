import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/widgets/group_form_sheet.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/subjects/widgets/subject_form_sheet.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final groupAsync = ref.watch(_groupProvider(groupId));
    final subjectsAsync = ref.watch(subjectsInGroupProvider(groupId));

    final group = groupAsync.value;
    return EdgeScaffold(
      actions: [
        // Attendance affordance only when the viewer can take attendance.
        if (viewer.canTakeAttendance)
          IconButton(
            tooltip: 'Take attendance',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => context.push('/groups/$groupId/attendance'),
          ),
        // Edit classroom is a program-management action.
        if (group != null && viewer.canManageProgram)
          IconButton(
            tooltip: 'Edit classroom',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => GroupFormSheet.show(context, group: group),
          ),
        const SyncStatusIndicator(),
      ],
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load students',
        ),
        data: (subjects) {
          if (subjects.isEmpty) {
            return EmptyState(
              icon: Icons.child_care_outlined,
              title: 'No students yet',
              message:
                  'Add your first student to start taking attendance '
                  'and logging observations.',
              action: FilledButton.icon(
                onPressed: () => SubjectFormSheet.show(
                  context,
                  groupId: groupId,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add student'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: subjects.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: group?.name ?? 'Classroom',
                    subtitle: group?.ageRange,
                  ),
                );
              }
              return _SubjectTile(subject: subjects[i - 1]);
            },
          );
        },
      ),
      floatingActionButton: subjectsAsync.maybeWhen(
        // Adding students is a program-management action; teachers
        // record on existing rosters but don't create them.
        data: (s) => (s.isEmpty || !viewer.canManageProgram)
            ? null
            : FloatingActionButton.extended(
                onPressed: () => SubjectFormSheet.show(
                  context,
                  groupId: groupId,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Student'),
              ),
        orElse: () => null,
      ),
    );
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _groupProvider = StreamProvider.family<Group?, String>(
  (ref, groupId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchGroup(groupId);
  },
);

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final ageLine = _ageLine(subject.dob);
    final fullName = '${subject.firstName} ${subject.lastName}';

    return ListTile(
      leading: PersonAvatar(
        name: fullName,
        photoUrl: subject.photoUrl,
      ),
      title: Text(fullName),
      subtitle: ageLine == null ? null : Text(ageLine),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => SubjectFormSheet.show(
        context,
        groupId: subject.groupId ?? '',
        subject: subject,
      ),
    );
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
