import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/groups/widgets/group_form_sheet.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home screen: "what's happening today across my classrooms."
///
/// Per the v1 punch list (docs/PROJECT.md): the teacher's morning
/// landing, glanceable status, fast access to today's attendance.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(currentMemberProvider).value;
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          const SyncStatusIndicator(),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load today',
          ),
          data: (groups) {
            if (groups.isEmpty) {
              return EmptyState(
                icon: Icons.meeting_room_outlined,
                title: 'No classrooms yet',
                message: 'Add your first classroom to start taking '
                    'attendance and logging the day.',
                action: FilledButton.icon(
                  onPressed: () => GroupFormSheet.show(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add classroom'),
                ),
              );
            }
            return _TodayBody(member: member, groups: groups);
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

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.member, required this.groups});

  final Member? member;
  final List<Group> groups;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = FormFactor.fromWidth(constraints.maxWidth);
        final padding = formFactor.isExpanded
            ? const EdgeInsets.symmetric(horizontal: 48, vertical: 24)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 16);

        return ListView(
          padding: padding,
          children: [
            _Greeting(member: member),
            const SizedBox(height: 24),
            _SectionHeader(
              label: 'Your classrooms',
              count: groups.length,
            ),
            const SizedBox(height: 8),
            ...groups.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GroupTodayCard(group: g),
                )),
          ],
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.member});

  final Member? member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = greetingForTime(DateTime.now());
    final name = member?.displayName ?? '';
    final today = DateTime.now();
    final dayLabel = _dayLabel(today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? '$greeting.' : '$greeting, $name.',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          dayLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _dayLabel(DateTime when) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final dow = days[when.weekday - 1];
    final mon = months[when.month - 1];
    return '$dow, $mon ${when.day}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

/// Per-group card on the Today screen: name, today's attendance state,
/// quick action.
class _GroupTodayCard extends ConsumerWidget {
  const _GroupTodayCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(groupDayStateProvider(group));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/groups/${group.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.meeting_room_outlined),
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
                  IconButton(
                    tooltip: 'Take attendance',
                    icon: const Icon(Icons.fact_check_outlined),
                    onPressed: () =>
                        context.go('/groups/${group.id}/attendance'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              stateAsync.when(
                loading: () => const _StateLine(
                  text: 'Loading attendance…',
                  color: null,
                ),
                error: (_, _) => const _StateLine(
                  text: 'Could not load attendance.',
                  color: null,
                ),
                data: (state) => _DayStateRow(state: state),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayStateRow extends StatelessWidget {
  const _DayStateRow({required this.state});

  final GroupDayState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (state.totalSubjects == 0) {
      return _StateLine(
        text: 'No students enrolled yet.',
        color: scheme.onSurfaceVariant,
      );
    }
    if (state.isComplete) {
      return _StateLine(
        text: 'All ${state.totalSubjects} students marked.',
        color: scheme.primary,
      );
    }
    if (state.markedCount == 0) {
      return _StateLine(
        text: '${state.totalSubjects} students • none marked yet',
        color: scheme.error,
      );
    }

    // Mixed state: show breakdown.
    final pieces = <Widget>[
      _StatusPill(
        status: null,
        label: '${state.unmarked} unmarked',
        color: scheme.error,
      ),
    ];
    for (final s in AttendanceStatus.values) {
      final n = state.counts[s] ?? 0;
      if (n == 0) continue;
      pieces.add(
        _StatusPill(
          status: s,
          label: '$n ${s.label.toLowerCase()}',
          color: s.color(scheme),
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: pieces);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.label,
    required this.color,
  });

  final AttendanceStatus? status;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(status!.icon, size: 14, color: color),
            ),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StateLine extends StatelessWidget {
  const _StateLine({required this.text, required this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: color ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
