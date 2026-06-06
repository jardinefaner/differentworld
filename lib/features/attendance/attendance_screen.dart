import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/attendance/widgets/attendance_row.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Daily attendance for a single Group. Per-Subject status, optimistic
/// writes, date scrubber, "Mark all present" shortcut.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({
    required this.groupId,
    this.initialDate,
    super.key,
  });

  final String groupId;
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

  String get _isoDate => dateKey(_date);

  DateTime get _todayMidnight {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _canGoForward => _date.isBefore(_todayMidnight);

  void _shiftDay(int days) {
    final next = _date.add(Duration(days: days));
    if (next.isAfter(_todayMidnight)) return; // clamp at today
    setState(() => _date = next);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: _todayMidnight,
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  String _dateLabel() {
    final diff = _date.difference(_todayMidnight).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    return _isoDate;
  }

  Future<void> _markAllPresent(
    List<Subject> subjects,
    AsyncValue<List<AttendanceRecord>> recordsAsync,
  ) async {
    unawaited(HapticFeedback.mediumImpact());
    final actions = ref.read(attendanceActionsProvider);
    final records = recordsAsync.value ?? const <AttendanceRecord>[];
    final marked = await actions.markAllPresent(
      groupId: widget.groupId,
      date: _isoDate,
      subjectIds: subjects.map((s) => s.id).toList(),
      alreadyRecordedSubjectIds: records.map((r) => r.subjectId).toList(),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (marked.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Everyone is already marked.')),
      );
      return;
    }
    // Longer window with a clear visible affordance — bulk operations
    // are easy to fat-finger; an 8-second window gives the user time
    // to react. The actual countdown ring lives on the FAB during the
    // window so the affordance is unmissable.
    messenger.showSnackBar(
      SnackBar(
        content: Text('Marked ${marked.length} present.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await actions.undoBulkPresent(date: _isoDate, subjectIds: marked);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final labels = ref.watch(verticalLabelsProvider);
    final groupAsync = ref.watch(_groupDetailProvider(widget.groupId));
    final subjectsAsync = ref.watch(subjectsInGroupProvider(widget.groupId));
    final recordsAsync = ref.watch(
      attendanceForDayProvider(
        (groupId: widget.groupId, date: _isoDate),
      ),
    );

    // Deep-link defence: anyone navigating to /groups/:id/attendance
    // without canTakeAttendance gets the deny-state, not a half-shown
    // attendance UI.
    if (!viewer.canTakeAttendance) {
      return const EdgeScaffold(body: NoAccess());
    }

    return EdgeScaffold(
      actions: [
        if (subjectsAsync.value?.isNotEmpty ?? false)
          PrimaryActionButton(
            tooltip: 'Mark all present',
            icon: Icons.check_circle_outline,
            onPressed: () =>
                _markAllPresent(subjectsAsync.value!, recordsAsync),
          ),
        const SyncStatusIndicator(),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The roster column, capped + centered so wide-and-short rows don't
          // stretch into ribbons on desktop/web.
          final content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ContentHeader(
                      title: 'Attendance',
                      subtitle: groupAsync.value?.name,
                      bottomGap: 8,
                    ),
                  ),
                  _DateScrubber(
                    label: _dateLabel(),
                    canGoForward: _canGoForward,
                    onPrev: () => _shiftDay(-1),
                    onNext: () => _shiftDay(1),
                    onTapLabel: _pickDate,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: subjectsAsync.when(
                      loading: () => const LoadingSlot(),
                      error: (e, _) => ErrorState(
                        title: 'Could not load students',
                        onRetry: () => ref.invalidate(
                          subjectsInGroupProvider(widget.groupId),
                        ),
                      ),
                      data: (subjects) {
                        if (subjects.isEmpty) {
                          return EmptyState(
                            icon: Icons.child_care_outlined,
                            title:
                                'No ${labels.subjectPlural.toLowerCase()} '
                                'in this ${labels.group.toLowerCase()}',
                            message:
                                'Add ${labels.subjectPlural.toLowerCase()} '
                                'first, then come back to take '
                                '${labels.attendanceNoun.toLowerCase()}.',
                          );
                        }
                        return recordsAsync.when(
                          loading: () => const LoadingSlot(),
                          error: (e, _) => ErrorState(
                            title: 'Could not load attendance',
                            onRetry: () => ref.invalidate(
                              attendanceForDayProvider(
                                (groupId: widget.groupId, date: _isoDate),
                              ),
                            ),
                          ),
                          data: (records) => _AttendanceList(
                            groupId: widget.groupId,
                            date: _isoDate,
                            subjects: subjects,
                            records: records,
                          ),
                        );
                      },
                    ),
                  ),
                  _SummaryBar(
                    subjects: subjectsAsync.value,
                    records: recordsAsync.value,
                  ),
                ],
              ),
            ),
          );
          // Desktop: a group-switcher rail beside the roster so a director can
          // hop between classrooms without leaving the screen. Phone: just the
          // capped roster (you arrived here for THIS group). "Mark all present"
          // stays in the top-right action pill.
          if (constraints.maxWidth >= Breakpoints.tablet) {
            return Row(
              children: [
                SizedBox(
                  width: 260,
                  child: _GroupRail(selectedId: widget.groupId),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            );
          }
          return content;
        },
      ),
    );
  }
}

/// Desktop-only left rail: every classroom, the current one highlighted; tap
/// to switch which group's attendance is showing (replaces the route so the
/// back stack doesn't pile up). Hidden below [Breakpoints.tablet], where you
/// reach attendance per-group from the classroom and don't need a switcher.
class _GroupRail extends ConsumerWidget {
  const _GroupRail({required this.selectedId});

  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'CLASSROOMS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        for (final g in groups)
          ListTile(
            dense: true,
            selected: g.id == selectedId,
            selectedTileColor: theme.colorScheme.primaryContainer.withValues(
              alpha: 0.5,
            ),
            leading: Icon(
              Icons.meeting_room_outlined,
              color: g.id == selectedId
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(g.name, overflow: TextOverflow.ellipsis),
            onTap: g.id == selectedId
                ? null
                : () => context.replace('/groups/${g.id}/attendance'),
          ),
      ],
    );
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _groupDetailProvider = StreamProvider.family<Group?, String>(
  (ref, groupId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.groupsDao.watchById(groupId);
  },
);

/// Thicker, more legible scrubber: chevron buttons on the sides and a
/// large central pill showing the day label. The pill is tappable to
/// open a date picker, mirroring the iOS Calendar pattern. Replaces
/// the IconButton + TextButton row that read as a thin nav strip.
class _DateScrubber extends StatelessWidget {
  const _DateScrubber({
    required this.label,
    required this.canGoForward,
    required this.onPrev,
    required this.onNext,
    required this.onTapLabel,
  });

  final String label;
  final bool canGoForward;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTapLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            tooltip: 'Previous day',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTapLabel,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoForward ? onNext : null,
            tooltip: canGoForward ? 'Next day' : 'No future days',
          ),
        ],
      ),
    );
  }
}

class _AttendanceList extends ConsumerWidget {
  const _AttendanceList({
    required this.groupId,
    required this.date,
    required this.subjects,
    required this.records,
  });

  final String groupId;
  final String date;
  final List<Subject> subjects;
  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Map subject id → current status for fast row lookup.
    final bySubject = <String, AttendanceStatus>{};
    // Wave 105: also keep the full record so the row can render the
    // audit footnote when a co-teacher overwrote the original write.
    final recordBySubject = <String, AttendanceRecord>{};
    for (final r in records) {
      final s = AttendanceStatus.fromDb(r.status);
      if (s != null) bySubject[r.subjectId] = s;
      recordBySubject[r.subjectId] = r;
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        0,
        4,
        0,
        96,
      ), // bottom clearance for FAB
      itemCount: subjects.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final subject = subjects[i];
        final scheme = Theme.of(context).colorScheme;
        Future<void> apply(AttendanceStatus? next) async {
          if (next == null) {
            await ref
                .read(attendanceActionsProvider)
                .clearStatus(
                  subjectId: subject.id,
                  date: date,
                );
          } else {
            await ref
                .read(attendanceActionsProvider)
                .setStatus(
                  groupId: groupId,
                  subjectId: subject.id,
                  date: date,
                  status: next,
                );
          }
        }

        // Swipe accelerator: → marks Present, ← marks Absent. Both
        // return `false` from confirmDismiss so the row doesn't
        // animate off — we just want the gesture as a faster way to
        // hit the two most common statuses. The inline icons in
        // AttendanceRow remain the canonical control for everything
        // else.
        return Dismissible(
          key: ValueKey('att-${subject.id}-$date'),
          background: Container(
            alignment: Alignment.centerLeft,
            color: AttendanceStatus.present
                .color(scheme)
                .withValues(
                  alpha: 0.20,
                ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  AttendanceStatus.present.icon,
                  color: AttendanceStatus.present.color(scheme),
                ),
                const SizedBox(width: 8),
                Text(
                  'Mark present',
                  style: TextStyle(
                    color: AttendanceStatus.present.color(scheme),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            color: AttendanceStatus.absent
                .color(scheme)
                .withValues(
                  alpha: 0.20,
                ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Mark absent',
                  style: TextStyle(
                    color: AttendanceStatus.absent.color(scheme),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  AttendanceStatus.absent.icon,
                  color: AttendanceStatus.absent.color(scheme),
                ),
              ],
            ),
          ),
          confirmDismiss: (dir) async {
            unawaited(HapticFeedback.mediumImpact());
            await apply(
              dir == DismissDirection.startToEnd
                  ? AttendanceStatus.present
                  : AttendanceStatus.absent,
            );
            return false; // never actually dismiss the row
          },
          child: AttendanceRow(
            subject: subject,
            status: bySubject[subject.id],
            onChangeStatus: apply,
            // Wave 105: pass the record so the row can surface the
            // "Updated by X · 2m ago" footnote when a co-teacher
            // overwrote the original write.
            record: recordBySubject[subject.id],
          ),
        );
      },
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.subjects, required this.records});

  final List<Subject>? subjects;
  final List<AttendanceRecord>? records;

  @override
  Widget build(BuildContext context) {
    if (subjects == null || records == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final counts = <AttendanceStatus, int>{};
    for (final r in records!) {
      final s = AttendanceStatus.fromDb(r.status);
      if (s != null) counts[s] = (counts[s] ?? 0) + 1;
    }
    final marked = counts.values.fold<int>(0, (a, b) => a + b);
    final unmarked = subjects!.length - marked;

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ...AttendanceStatus.values.where((s) => (counts[s] ?? 0) > 0).map(
                (s) {
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
                },
              ),
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
