import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/groups/widgets/group_form_sheet.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

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
        child: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => const EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load classrooms',
          ),
          data: (groups) {
            if (groups.isEmpty) {
              return EmptyState(
                icon: Icons.meeting_room_outlined,
                title: 'No classrooms yet',
                message: 'Add your first classroom to start organizing '
                    'students, plans, and attendance.',
                action: FilledButton.icon(
                  onPressed: () => GroupFormSheet.show(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add classroom'),
                ),
              );
            }
            return _GroupsList(groups: groups);
          },
        ),
      ),
      floatingActionButton: groupsAsync.maybeWhen(
        data: (groups) => groups.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => GroupFormSheet.show(context),
                icon: const Icon(Icons.add),
                label: const Text('Classroom'),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _GroupsList extends StatelessWidget {
  const _GroupsList({required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = FormFactor.fromWidth(constraints.maxWidth);
        final useGrid = formFactor != FormFactor.phone;
        if (useGrid) {
          final crossAxisCount = formFactor == FormFactor.desktop ? 4 : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: groups.length,
            itemBuilder: (_, i) => _GroupCard(group: groups[i]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: groups.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _GroupTile(group: groups[i]),
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.meeting_room_outlined)),
      title: Text(group.name),
      subtitle: group.ageRange == null ? null : Text(group.ageRange!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go('/groups/${group.id}'),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/groups/${group.id}'),
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
                      group.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (group.ageRange != null)
                      Text(
                        group.ageRange!,
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
