import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/attendance/widgets/attendance_row.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Bulk-mark gating: the first tap arms; the second tap (within ~3
  /// seconds) actually fires. Avoids accidental sweeps across N rooms.
  bool _armed = false;
  Timer? _armTimer;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter == 'unmarked'
        ? _Filter.unmarked
        : _Filter.everyone;
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  void _armBulk() {
    _armTimer?.cancel();
    setState(() => _armed = true);
    _armTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _armed = false);
    });
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
    final viewer = ref.watch(viewerProvider);
    final dataAsync = ref.watch(_morningChecklistProvider(_isoDate));

    // Daily-log roles only. Director-without-attendance can still see
    // it (their bundle defaults canTakeAttendance true), but the rare
    // viewer that ONLY views (future kiosk / family) gets the deny.
    if (!viewer.isDailyLogger) {
      return const EdgeScaffold(body: NoAccess());
    }

    // Compute the bulk-mark state once so both the actions row and
    // (formerly) the FAB read from the same numbers.
    final sections = dataAsync.value;
    final totalUnmarked = sections == null
        ? 0
        : sections.fold<int>(0, (acc, s) {
            final marked = s.records.map((r) => r.subjectId).toSet();
            return acc +
                s.subjects
                    .where((sub) => !marked.contains(sub.id))
                    .length;
          });
    final canBulk = sections != null &&
        sections.isNotEmpty &&
        totalUnmarked > 0;
    final scheme = Theme.of(context).colorScheme;

    return EdgeScaffold(
      actions: [
        if (canBulk)
          // 2-stage mark-all-present primary. First tap arms with the
          // error tint + "Tap again · N kids"; second tap fires. Auto-
          // disarms after 4 seconds via _armBulk.
          Material(
            color: _armed
                ? scheme.error
                : scheme.primaryContainer,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                if (!_armed) {
                  unawaited(HapticFeedback.selectionClick());
                  _armBulk();
                  return;
                }
                _armTimer?.cancel();
                setState(() => _armed = false);
                await _markAllPresentEverywhere(sections);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _armed
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: 18,
                      color: _armed
                          ? scheme.onError
                          : scheme.onPrimaryContainer,
                    ),
                    if (_armed) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Tap again · $totalUnmarked',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: scheme.onError,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        const SyncStatusIndicator(),
      ],
      body: dataAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the checklist',
          onRetry: () => ref.invalidate(_morningChecklistProvider(_isoDate)),
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
            subtitle: _filter == _Filter.unmarked
                ? 'Only students with no status yet'
                : 'Every student, every classroom',
            onFilterChanged: (f) => setState(() => _filter = f),
          );
        },
      ),
      // FAB removed — 2-stage Mark-all-present lives in the
      // top-right primary action pill (see actions above).
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
    required this.subtitle,
    required this.onFilterChanged,
  });

  final List<_Section> sections;
  final _Filter filter;
  final String date;
  final String subtitle;
  final ValueChanged<_Filter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aggregate counts for the filter chips so the user knows what's
    // hiding behind each option before they switch.
    var totalKids = 0;
    var totalUnmarked = 0;
    final filteredSections = <_Section>[];
    for (final s in sections) {
      final markedIds = <String>{
        for (final r in s.records)
          if (AttendanceStatus.fromDb(r.status) != null) r.subjectId,
      };
      totalKids += s.subjects.length;
      totalUnmarked +=
          s.subjects.where((sub) => !markedIds.contains(sub.id)).length;
      final keep = filter == _Filter.unmarked
          ? s.subjects.any((sub) => !markedIds.contains(sub.id))
          : s.subjects.isNotEmpty;
      if (keep) filteredSections.add(s);
    }

    if (filteredSections.isEmpty) {
      if (filter == _Filter.unmarked) {
        // Celebration: this is the rare feel-good moment in the daily
        // slog; give it pixels. Bigger icon, a single concrete stat
        // ("4 classrooms · 23 kids") so the win feels quantified.
        final rooms = sections.length;
        final kids = totalKids;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Done for today.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$rooms ${rooms == 1 ? 'classroom' : 'classrooms'} · '
                  '$kids ${kids == 1 ? 'kid' : 'kids'} accounted for.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Nice work.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        );
      }
      return const EmptyState(
        icon: Icons.task_alt,
        title: 'No students to show',
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(
              title: 'Morning checklist',
              subtitle: subtitle,
              bottomGap: 8,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<_Filter>(
              segments: [
                ButtonSegment(
                  value: _Filter.everyone,
                  label: Text('Everyone · $totalKids'),
                ),
                ButtonSegment(
                  value: _Filter.unmarked,
                  label: Text('Unmarked · $totalUnmarked'),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (s) {
                if (s.isNotEmpty) onFilterChanged(s.first);
              },
              showSelectedIcon: false,
            ),
          ),
        ),
        for (final s in filteredSections)
          _buildSectionSliver(context, ref, s),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildSectionSliver(
    BuildContext context,
    WidgetRef ref,
    _Section s,
  ) {
    final byId = <String, AttendanceStatus>{};
    for (final r in s.records) {
      final st = AttendanceStatus.fromDb(r.status);
      if (st != null) byId[r.subjectId] = st;
    }
    final filtered = filter == _Filter.unmarked
        ? s.subjects.where((sub) => byId[sub.id] == null).toList()
        : s.subjects;
    final marked = byId.length;
    final total = s.subjects.length;

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedSectionHeader(
            title: s.group.name,
            ageRange: s.group.ageRange,
            marked: marked,
            total: total,
          ),
        ),
        SliverList.builder(
          itemCount: filtered.length,
          itemBuilder: (_, i) => _ChecklistRow(
            groupId: s.group.id,
            subject: filtered[i],
            status: byId[filtered[i].id],
            date: date,
          ),
        ),
      ],
    );
  }
}

class _PinnedSectionHeader extends SliverPersistentHeaderDelegate {
  _PinnedSectionHeader({
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
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Tint slightly when pinned and content scrolled underneath so
    // the header reads as a header, not a free-floating row.
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (ageRange != null && ageRange!.isNotEmpty)
                  Text(
                    ageRange!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$marked / $total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_PinnedSectionHeader old) =>
      old.title != title ||
      old.ageRange != ageRange ||
      old.marked != marked ||
      old.total != total;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AttendanceRow(
      subject: subject,
      status: status,
      onChangeStatus: (next) async {
        if (next == null) {
          await ref.read(attendanceActionsProvider).clearStatus(
                subjectId: subject.id,
                date: date,
              );
        } else {
          await ref.read(attendanceActionsProvider).setStatus(
                groupId: groupId,
                subjectId: subject.id,
                date: date,
                status: next,
              );
        }
      },
    );
  }
}
