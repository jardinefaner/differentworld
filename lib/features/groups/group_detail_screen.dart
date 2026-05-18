import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/groups/widgets/group_form_sheet.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/subjects/widgets/subject_form_sheet.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(_groupProvider(groupId));
    final subjectsAsync = ref.watch(subjectsInGroupProvider(groupId));

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
        title: groupAsync.when(
          loading: () => const Text('Classroom'),
          error: (_, _) => const Text('Classroom'),
          data: (g) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(g?.name ?? 'Classroom'),
              if (g?.ageRange != null)
                Text(
                  g!.ageRange!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Take attendance',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => context.go('/groups/$groupId/attendance'),
          ),
          if (groupAsync.value != null)
            IconButton(
              tooltip: 'Edit classroom',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => GroupFormSheet.show(
                context,
                group: groupAsync.value,
              ),
            ),
          const SyncStatusIndicator(),
        ],
      ),
      body: SafeArea(
        child: subjectsAsync.when(
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
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: subjects.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _SubjectTile(subject: subjects[i]),
            );
          },
        ),
      ),
      floatingActionButton: subjectsAsync.maybeWhen(
        data: (s) => s.isEmpty
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
    final theme = Theme.of(context);
    final initials = _initials(subject.firstName, subject.lastName);
    final ageLine = _ageLine(subject.dob);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Text(initials),
      ),
      title: Text('${subject.firstName} ${subject.lastName}'),
      subtitle: ageLine == null ? null : Text(ageLine),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => SubjectFormSheet.show(
        context,
        groupId: subject.groupId ?? '',
        subject: subject,
      ),
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
