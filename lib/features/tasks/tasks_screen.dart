import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/tasks` — open to-dos for the program. Filter chips pick a horizon
/// (Today / Week / Overdue / All); the body is grouped into Overdue →
/// Today → This week → Later so the next thing to do is always at the
/// top of the page.
///
/// Tap a row to mark it done; swipe a row to dismiss.
enum _TaskFilter { today, week, overdue, all }

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  // URL-state: the filter chip lives in the query string so a refresh /
  // bookmark / share keeps the user on the same horizon.
  // `/tasks?filter=overdue` etc.
  static const _filterParam = 'filter';

  _TaskFilter _filterFromUri(Uri uri) {
    final raw = uri.queryParameters[_filterParam];
    return switch (raw) {
      'week' => _TaskFilter.week,
      'overdue' => _TaskFilter.overdue,
      'all' => _TaskFilter.all,
      _ => _TaskFilter.today,
    };
  }

  String _filterName(_TaskFilter f) => switch (f) {
        _TaskFilter.today => 'today',
        _TaskFilter.week => 'week',
        _TaskFilter.overdue => 'overdue',
        _TaskFilter.all => 'all',
      };

  void _setFilter(BuildContext context, _TaskFilter next) {
    // Use `replace` (not `go`) so the back button doesn't accumulate
    // a history entry per filter tap — the user's expectation is that
    // back exits the screen, not "back through filters."
    context.replace('/tasks?$_filterParam=${_filterName(next)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = _filterFromUri(GoRouterState.of(context).uri);
    final tasksAsync = ref.watch(openTasksProvider);
    return EdgeScaffold(
      actions: [
        PrimaryActionButton(
          tooltip: 'New task',
          icon: Icons.add,
          onPressed: () => context.push('/tasks/new'),
        ),
        const SyncStatusIndicator(),
      ],
      body: tasksAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load tasks',
          onRetry: () => ref.invalidate(openTasksProvider),
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
                onPressed: () => context.push('/tasks/new'),
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
            );
          }
          final buckets = _bucketize(tasks);
          final scoped = _scopeToFilter(buckets, filter);
          final scopedCount = scoped.values.fold<int>(
            0,
            (a, b) => a + b.length,
          );

          return ResponsivePage(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: 'Tasks',
                  subtitle:
                      'Open to-dos. Tap to mark done; swipe a row to dismiss.',
                  bottomGap: 8,
                ),
              ),
              // Horizon chips — always show all four; the count badge on
              // each tells the user what's in there before they switch.
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _FilterChip(
                      label: 'Today',
                      count: buckets[_Bucket.today]?.length ?? 0,
                      selected: filter == _TaskFilter.today,
                      onTap: () => _setFilter(context, _TaskFilter.today),
                    ),
                    _FilterChip(
                      label: 'This week',
                      count:
                          (buckets[_Bucket.today]?.length ?? 0) +
                          (buckets[_Bucket.thisWeek]?.length ?? 0),
                      selected: filter == _TaskFilter.week,
                      onTap: () => _setFilter(context, _TaskFilter.week),
                    ),
                    _FilterChip(
                      label: 'Overdue',
                      count: buckets[_Bucket.overdue]?.length ?? 0,
                      selected: filter == _TaskFilter.overdue,
                      emphasize: true,
                      onTap: () => _setFilter(context, _TaskFilter.overdue),
                    ),
                    _FilterChip(
                      label: 'All',
                      count: tasks.length,
                      selected: filter == _TaskFilter.all,
                      onTap: () => _setFilter(context, _TaskFilter.all),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (scopedCount == 0)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      filter == _TaskFilter.overdue
                          ? 'Nothing overdue. Nice.'
                          : 'Nothing in this horizon — try a wider one.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final bucket in _Bucket.values)
                  if ((scoped[bucket] ?? const <Task>[]).isNotEmpty) ...[
                    _BucketHeader(label: bucket.label),
                    for (final t in scoped[bucket]!)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: _TaskCard(
                          task: t,
                          overdueBucket: bucket == _Bucket.overdue,
                        ),
                      ),
                  ],
            ],
          );
        },
      ),
    );
  }

  /// Bucket every task by its due-date relationship to today.
  static Map<_Bucket, List<Task>> _bucketize(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfWeek = today.add(const Duration(days: 7));
    final result = {for (final b in _Bucket.values) b: <Task>[]};
    for (final t in tasks) {
      final due = t.dueAt == null ? null : DateTime.tryParse(t.dueAt!);
      if (due == null) {
        result[_Bucket.later]!.add(t);
        continue;
      }
      final dueDay = DateTime(due.year, due.month, due.day);
      if (due.isBefore(now) && dueDay.isBefore(today)) {
        result[_Bucket.overdue]!.add(t);
      } else if (dueDay == today) {
        result[_Bucket.today]!.add(t);
      } else if (dueDay.isBefore(endOfWeek)) {
        result[_Bucket.thisWeek]!.add(t);
      } else {
        result[_Bucket.later]!.add(t);
      }
    }
    return result;
  }

  static Map<_Bucket, List<Task>> _scopeToFilter(
    Map<_Bucket, List<Task>> buckets,
    _TaskFilter filter,
  ) {
    return switch (filter) {
      _TaskFilter.today => {
        _Bucket.overdue: buckets[_Bucket.overdue]!,
        _Bucket.today: buckets[_Bucket.today]!,
      },
      _TaskFilter.week => {
        _Bucket.overdue: buckets[_Bucket.overdue]!,
        _Bucket.today: buckets[_Bucket.today]!,
        _Bucket.thisWeek: buckets[_Bucket.thisWeek]!,
      },
      _TaskFilter.overdue => {
        _Bucket.overdue: buckets[_Bucket.overdue]!,
      },
      _TaskFilter.all => buckets,
    };
  }
}

enum _Bucket {
  overdue('Overdue'),
  today('Today'),
  thisWeek('This week'),
  later('Later')
  ;

  const _Bucket(this.label);
  final String label;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.emphasize = false,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  /// Overdue gets a subtle error tint even when unselected — its
  /// count is the one a user wants to see at a glance.
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected
        ? scheme.onPrimary
        : (emphasize && count > 0 ? scheme.error : scheme.onSurface);
    final bg = selected
        ? scheme.primary
        : (emphasize && count > 0
              ? scheme.errorContainer.withValues(alpha: 0.45)
              : scheme.surfaceContainerHighest);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(color: fg),
                ),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.7),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BucketHeader extends StatelessWidget {
  const _BucketHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = label == 'Overdue';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: isOverdue
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.overdueBucket});
  final Task task;

  /// True iff the task lives in the Overdue bucket. We tint the whole
  /// card errorContainer in that case — your eye finds them in a long
  /// list immediately.
  final bool overdueBucket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = task.dueAt == null ? null : DateTime.tryParse(task.dueAt!);
    final created = DateTime.tryParse(task.createdAt)?.toLocal();
    final overdue =
        due != null &&
        due.isBefore(DateTime.now()) &&
        task.status == TaskStatus.open;
    return Dismissible(
      key: ValueKey('task-${task.id}'),
      // Right swipe (start→end) snoozes 1 day. Left swipe (end→start)
      // dismisses. The two states for the most common follow-ups; tap
      // the radio button to complete.
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.tertiaryContainer,
        child: Row(
          children: [
            Icon(
              Icons.snooze,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              'Snooze · +1 day',
              style: TextStyle(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: theme.colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (dir) async {
        unawaited(HapticFeedback.mediumImpact());
        if (dir == DismissDirection.startToEnd) {
          await ref.read(taskActionsProvider).snooze(id: task.id);
          return false; // don't actually dismiss; stream will reorder
        }
        return true; // left-swipe = real dismiss
      },
      onDismissed: (_) async {
        await ref.read(taskActionsProvider).discard(task.id);
      },
      child: Material(
        color: overdueBucket
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.45)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tap the radio button to complete — the row body opens
              // edit (TBD). Separating completes vs. opens avoids
              // accidental closes when users tap to read more.
              Tooltip(
                message: 'Mark done',
                // Wave 97: bumped padding 10 → 12 so the radius
                // grows from 44 to 48 (matches Material's tap target
                // minimum). The icon stays 24dp so the visual is the
                // same; just more forgiving for the next 50,000
                // taps a teacher does in their career.
                child: InkResponse(
                  radius: 24,
                  onTap: () async {
                    unawaited(HapticFeedback.mediumImpact());
                    await ref.read(taskActionsProvider).markDone(task.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.radio_button_unchecked,
                      color: overdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
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
                                fontWeight: overdue ? FontWeight.w700 : null,
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
              ),
            ],
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
