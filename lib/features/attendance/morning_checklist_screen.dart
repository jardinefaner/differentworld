import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/attendance/widgets/status_picker_sheet.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "Morning checklist" — every student in every classroom on today's
/// date, grouped by classroom. One scroll, swipe / tap to mark, done.
///
/// Per the UX audit's B1 recommendation: this is the daily-use core
/// loop reframed away from "directory of rooms" toward "list of today's
/// work". The existing per-classroom AttendanceScreen still exists for
/// drill-down; this is the at-a-glance superset.
class MorningChecklistScreen extends ConsumerStatefulWidget {
  const MorningChecklistScreen({this.initialFilter, super.key});

  /// 'unmarked' to start filtered to students with no status yet, or
  /// null for "everyone".
  final String? initialFilter;

  @override
  ConsumerState<MorningChecklistScreen> createState() =>
      _MorningChecklistScreenState();
}

enum _Filter { everyone, unmarked }

class _MorningChecklistScreenState
    extends ConsumerState<MorningChecklistScreen> {
  late _Filter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter == 'unmarked'
        ? _Filter.unmarked
        : _Filter.everyone;
  }

  String get _isoDate {
    final n = DateTime.now();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _markAllPresentEverywhere(
    List<({Group group, List<Subject> subjects, List<AttendanceRecord> records})>
        sections,
  ) async {
    unawaited(HapticFeedback.mediumImpact());
    final actions = ref.read(attendanceActionsProvider);
    final allTouched = <(String, String)>[]; // (groupId, subjectId)
    for (final s in sections) {
      final already = s.records.map((r) => r.subjectId).toList();
      final touched = await actions.markAllPresent(
        groupId: s.group.id,
        date: _isoDate,
        subjectIds: s.subjects.map((x) => x.id).toList(),
        alreadyRecordedSubjectIds: already,
      );
      for (final id in touched) {
        allTouched.add((s.group.id, id));
      }
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (allTouched.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Everyone is already marked.')),
      );
      return;
    }
    final byGroup = <String, List<String>>{};
    for (final entry in allTouched) {
      byGroup.putIfAbsent(entry.$1, () => []).add(entry.$2);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Marked ${allTouched.length} present.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            for (final entry in byGroup.entries) {
              await actions.undoBulkPresent(
                date: _isoDate,
                subjectIds: entry.value,
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataAsync = ref.watch(_morningChecklistProvider(_isoDate));

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
            const Text('Morning checklist'),
            Text(
              _filter == _Filter.unmarked
                  ? 'Only students with no status yet'
                  : 'Every student, every classroom',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_Filter>(
            tooltip: 'Filter',
            icon: Icon(
              _filter == _Filter.everyone
                  ? Icons.filter_list
                  : Icons.filter_alt,
            ),
            onSelected: (f) => setState(() => _filter = f),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: _Filter.everyone,
                checked: _filter == _Filter.everyone,
                child: const Text('Everyone'),
              ),
              CheckedPopupMenuItem(
                value: _Filter.unmarked,
                checked: _filter == _Filter.unmarked,
                child: const Text('Only unmarked'),
              ),
            ],
          ),
          const SyncStatusIndicator(),
        ],
      ),
      body: SafeArea(
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load the checklist',
          ),
          data: (sections) {
            if (sections.isEmpty) {
              return const EmptyState(
                icon: Icons.child_care_outlined,
                title: 'No students to check in',
                message:
                    'Add classrooms and students first; this list builds '
                    'itself.',
              );
            }
            return _ChecklistList(
              sections: sections,
              filter: _filter,
              date: _isoDate,
            );
          },
        ),
      ),
      floatingActionButton: dataAsync.maybeWhen(
        data: (sections) => sections.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _markAllPresentEverywhere(sections),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark all present'),
              ),
        orElse: () => null,
      ),
    );
  }
}

/// Composed view: every classroom in the current space + its subjects
/// + today's attendance records, all bundled per-classroom so the UI
/// can render section headers without re-joining.
typedef _Section = ({
  Group group,
  List<Subject> subjects,
  List<AttendanceRecord> records,
});

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _morningChecklistProvider =
    Provider.autoDispose.family<AsyncValue<List<_Section>>, String>(
  (ref, date) {
    final groupsAsync = ref.watch(groupsProvider);
    if (groupsAsync.isLoading) return const AsyncValue.loading();
    if (groupsAsync.hasError) {
      return AsyncError(groupsAsync.error!, groupsAsync.stackTrace!);
    }
    final groups = groupsAsync.value ?? const <Group>[];
    if (groups.isEmpty) return const AsyncValue.data([]);

    final sections = <_Section>[];
    var anyLoading = false;
    for (final g in groups) {
      final subs = ref.watch(subjectsInGroupProvider(g.id));
      final recs = ref.watch(
        attendanceForDayProvider((groupId: g.id, date: date)),
      );
      if (subs.isLoading || recs.isLoading) {
        anyLoading = true;
        continue;
      }
      final subjects = subs.value ?? const <Subject>[];
      if (subjects.isEmpty) continue; // skip empty rooms
      sections.add((
        group: g,
        subjects: subjects,
        records: recs.value ?? const <AttendanceRecord>[],
      ));
    }
    // Refuse to expose a partial list — the "Mark all present everywhere"
    // FAB would otherwise miss the classrooms still loading. Once
    // everything is in, emit the full set.
    if (anyLoading) return const AsyncValue.loading();
    return AsyncValue.data(sections);
  },
);

class _ChecklistList extends ConsumerWidget {
  const _ChecklistList({
    required this.sections,
    required this.filter,
    required this.date,
  });

  final List<_Section> sections;
  final _Filter filter;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <Widget>[];

    for (final s in sections) {
      final byId = <String, AttendanceStatus>{};
      for (final r in s.records) {
        final st = AttendanceStatus.fromDb(r.status);
        if (st != null) byId[r.subjectId] = st;
      }
      final filtered = filter == _Filter.unmarked
          ? s.subjects.where((sub) => byId[sub.id] == null).toList()
          : s.subjects;
      if (filtered.isEmpty) continue;

      final marked = byId.length;
      final total = s.subjects.length;
      items.add(_SectionHeader(
        title: s.group.name,
        ageRange: s.group.ageRange,
        marked: marked,
        total: total,
      ));
      for (final sub in filtered) {
        items.add(_ChecklistRow(
          groupId: s.group.id,
          subject: sub,
          status: byId[sub.id],
          date: date,
        ));
      }
    }

    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt,
        title: filter == _Filter.unmarked
            ? 'Nothing left to mark'
            : 'No students to show',
        message: filter == _Filter.unmarked
            ? 'Everyone has a status for today. Great work.'
            : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96), // FAB clearance
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.ageRange,
    required this.marked,
    required this.total,
  });

  final String title;
  final String? ageRange;
  final int marked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (ageRange != null && ageRange!.isNotEmpty)
                  Text(
                    ageRange!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$marked / $total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends ConsumerWidget {
  const _ChecklistRow({
    required this.groupId,
    required this.subject,
    required this.status,
    required this.date,
  });

  final String groupId;
  final Subject subject;
  final AttendanceStatus? status;
  final String date;

  String get _initials {
    String firstChar(String s) {
      final t = s.trim();
      return t.isEmpty ? '' : t.substring(0, 1).toUpperCase();
    }

    final j = '${firstChar(subject.firstName)}${firstChar(subject.lastName)}';
    return j.isEmpty ? '?' : j;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Text(_initials),
      ),
      title: Text('${subject.firstName} ${subject.lastName}'),
      trailing: _StatusChip(status: status),
      onTap: () async {
        unawaited(HapticFeedback.selectionClick());
        final picked = await StatusPickerSheet.show(
          context,
          studentName: '${subject.firstName} ${subject.lastName}',
          currentStatus: status,
        );
        if (picked != null) {
          await ref.read(attendanceActionsProvider).setStatus(
                groupId: groupId,
                subjectId: subject.id,
                date: date,
                status: picked,
              );
        }
      },
    );
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
