import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/features/tasks/widgets/task_sheet.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/tasks` — open to-dos for the program. Tap a row to mark it done;
/// tap the FAB to add one inline. Same calm scroll as the Capture
/// inbox.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(openTasksProvider);
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewTaskSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: tasksAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load tasks',
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No open tasks',
              message:
                  'Quiet for now. Tap New task to add one, or promote '
                  'a capture from /captures into a task instead of an '
                  'observation.',
              action: FilledButton.icon(
                onPressed: () => showNewTaskSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: 'Tasks',
                  subtitle:
                      'Open to-dos. Tap to mark done; '
                      'swipe a row to dismiss.',
                ),
              ),
              for (final t in tasks)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: _TaskCard(task: t),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = task.dueAt == null ? null : DateTime.tryParse(task.dueAt!);
    final created = DateTime.tryParse(task.createdAt)?.toLocal();
    final overdue =
        due != null && due.isBefore(DateTime.now()) && task.status == 'open';
    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) async {
        unawaited(HapticFeedback.mediumImpact());
        await ref.read(taskActionsProvider).discard(task.id);
      },
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            unawaited(HapticFeedback.selectionClick());
            await ref.read(taskActionsProvider).markDone(task.id);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    Icons.radio_button_unchecked,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.body,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (due != null) ...[
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: overdue
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _dueLabel(due, overdue: overdue),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: overdue
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight:
                                    overdue ? FontWeight.w700 : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            'Added ${relativeTimeAgo(created)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _dueLabel(DateTime due, {required bool overdue}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final days = dueDay.difference(today).inDays;
    if (overdue) return 'Overdue ${relativeTimeAgo(due)}';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days > 1 && days < 7) return 'Due in $days days';
    return 'Due ${relativeTimeAgo(due)}'.replaceFirst('ago', 'from now');
  }
}
