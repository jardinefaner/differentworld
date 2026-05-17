import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/classrooms/classrooms_providers.dart';
import 'package:differentworld/features/classrooms/widgets/classroom_form_sheet.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClassroomsListScreen extends ConsumerWidget {
  const ClassroomsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classroomsAsync = ref.watch(classroomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classrooms'),
        actions: [
          const SyncStatusIndicator(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authActionsProvider).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: classroomsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load classrooms',
            message: err.toString(),
          ),
          data: (classrooms) {
            if (classrooms.isEmpty) {
              return EmptyState(
                icon: Icons.meeting_room_outlined,
                title: 'No classrooms yet',
                message: 'Add your first classroom to start organizing '
                    'students, plans, and attendance.',
                action: FilledButton.icon(
                  onPressed: () => ClassroomFormSheet.show(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add classroom'),
                ),
              );
            }
            return _ClassroomsList(classrooms: classrooms);
          },
        ),
      ),
      floatingActionButton: classroomsAsync.maybeWhen(
        data: (rooms) => rooms.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => ClassroomFormSheet.show(context),
                icon: const Icon(Icons.add),
                label: const Text('Classroom'),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _ClassroomsList extends StatelessWidget {
  const _ClassroomsList({required this.classrooms});

  final List<Classroom> classrooms;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = FormFactor.fromWidth(constraints.maxWidth);
        final useGrid = formFactor != FormFactor.phone;
        if (useGrid) {
          // Tablet+: tile grid, easier to scan more rooms at a glance.
          final crossAxisCount = formFactor == FormFactor.desktop ? 4 : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: classrooms.length,
            itemBuilder: (_, i) => _ClassroomCard(classroom: classrooms[i]),
          );
        }
        // Phone: simple list.
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: classrooms.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _ClassroomTile(classroom: classrooms[i]),
        );
      },
    );
  }
}

class _ClassroomTile extends StatelessWidget {
  const _ClassroomTile({required this.classroom});

  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.meeting_room_outlined)),
      title: Text(classroom.name),
      subtitle: classroom.ageRange == null
          ? null
          : Text(classroom.ageRange!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/classrooms/${classroom.id}'),
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({required this.classroom});

  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/classrooms/${classroom.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.meeting_room_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      classroom.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (classroom.ageRange != null)
                      Text(
                        classroom.ageRange!,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
