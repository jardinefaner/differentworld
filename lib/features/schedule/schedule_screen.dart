import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/block_edit_sheet.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/widgets/substitute_lead_sheet.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// `/schedule` — staff-side schedule for one date. Cohort tabs across
/// the top; each tab shows the chronological list of blocks for that
/// cohort. The "+" FAB authors a new block in the current cohort.
///
/// Block boundaries are per-row (no fixed grid). Teachers set start
/// and end times directly when authoring.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with TickerProviderStateMixin {
  late DateTime _date;
  TabController? _tabs;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final n = widget.initialDate ?? DateTime.now();
    _date = DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    _tabs?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs == null) return;
    final i = _tabs!.index;
    if (i != _activeTabIndex) {
      setState(() => _activeTabIndex = i);
    }
  }

  /// Lazy-create the TabController once the group list is known. The
  /// length is determined by the cohort count, so we can't construct
  /// it in initState.
  TabController _ensureTabController(int length) {
    if (_tabs == null || _tabs!.length != length) {
      _tabs?.removeListener(_onTabChanged);
      _tabs?.dispose();
      _tabs = TabController(length: length, vsync: this);
      _tabs!.addListener(_onTabChanged);
      // Clamp the active index if cohorts changed.
      if (_activeTabIndex >= length) _activeTabIndex = 0;
    }
    return _tabs!;
  }

  String get _dateIso => isoDateLocal(_date);

  bool get _isToday {
    final n = DateTime.now();
    return n.year == _date.year &&
        n.month == _date.month &&
        n.day == _date.day;
  }

  String _dateLabel() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final delta = _date.difference(today).inDays;
    if (delta == 0) return 'Today';
    if (delta == 1) return 'Tomorrow';
    if (delta == -1) return 'Yesterday';
    return DateFormat.yMMMMEEEEd().format(_date);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _shiftDay(int days) {
    setState(() => _date = _date.add(Duration(days: days)));
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    final blocksAsync = ref.watch(scheduleDayProvider(_dateIso));
    final groups = groupsAsync.value ?? const <Group>[];
    final tabs = groups.isEmpty ? null : _ensureTabController(groups.length);

    // '+ Block' is a write — only viewers with canManageSchedule can
    // author blocks. Hide the chrome action for everyone else
    // (matches the hide-don't-disable rule) so a teacher without the
    // cap doesn't tap into a sheet they can't save from.
    final viewer = ref.watch(viewerProvider);
    final canEditSchedule = viewer.canManageSchedule || viewer.canManageSpace;
    return EdgeScaffold(
      showBack: false,
      actions: (groups.isEmpty || !canEditSchedule)
          ? const <Widget>[]
          : [
              PrimaryActionButton(
                tooltip: 'New block',
                icon: Icons.add,
                onPressed: () {
                  final cohort = groups[_activeTabIndex.clamp(
                    0,
                    groups.length - 1,
                  )];
                  unawaited(_openBlockSheet(
                    context,
                    ref,
                    groupId: cohort.id,
                    date: _date,
                    defaultStart: _defaultStartTime(),
                    existingBlocks:
                        blocksAsync.value ?? const <ScheduleBlock>[],
                  ));
                },
              ),
            ],
      body: groupsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load schedule',
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        data: (gs) {
          if (gs.isEmpty) {
            final labels = ref.read(verticalLabelsProvider);
            final groupLower = labels.group.toLowerCase();
            return EmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'No ${labels.groupPlural.toLowerCase()} yet',
              message:
                  'Add a $groupLower first; schedule blocks belong '
                  'to a specific $groupLower.',
            );
          }
          return Column(
            children: [
              // Shell reserves the top chrome height; ContentHeader's
              // own topGap (default 8) is just breathing room.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: 'Schedule',
                  subtitle: _dateLabel(),
                  bottomGap: 8,
                ),
              ),
              _DateScrubber(
                label: _dateLabel(),
                isToday: _isToday,
                onPrev: () => _shiftDay(-1),
                onNext: () => _shiftDay(1),
                onPickDate: _pickDate,
                onJumpToday: () => setState(
                  () => _date = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  ),
                ),
              ),
              TabBar(
                controller: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final g in gs) Tab(text: g.name)],
              ),
              Expanded(
                child: TabBarView(
                  controller: tabs,
                  children: [
                    for (final g in gs)
                      _CohortDay(group: g, date: _dateIso),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Next round half-hour from now (or 9 a.m. on a future date). The
  /// scheduler can override; this just seeds the time picker so the
  /// teacher doesn't start at "12:00 a.m." by default.
  DateTime _defaultStartTime() {
    final now = DateTime.now();
    if (now.year != _date.year ||
        now.month != _date.month ||
        now.day != _date.day) {
      return DateTime(_date.year, _date.month, _date.day, 9);
    }
    final mins = ((now.minute / 30).ceil()) * 30;
    return DateTime(now.year, now.month, now.day, now.hour, mins);
  }
}

class _DateScrubber extends StatelessWidget {
  const _DateScrubber({
    required this.label,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
    required this.onJumpToday,
  });

  final String label;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final VoidCallback onJumpToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onPickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isToday) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: onJumpToday,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              '· Today',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}

class _CohortDay extends ConsumerWidget {
  const _CohortDay({required this.group, required this.date});

  final Group group;
  final String date;

  /// We only surface the "Cover lead" action when the viewed date is
  /// TODAY — covering yesterday or a future day is nonsense (those
  /// blocks are either past or get re-edited at the block level).
  bool get _isToday => date == todayIsoLocal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(
      scheduleDayForGroupProvider((groupId: group.id, date: date)),
    );
    final activities = ref.watch(allActivitiesProvider).value ??
        const <Activity>[];
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];

    return blocksAsync.when(
      loading: () => const LoadingSlot(),
      error: (_, _) => ErrorState(
        title: "Couldn't load this cohort's schedule",
        onRetry: () => ref.invalidate(
          scheduleDayForGroupProvider((groupId: group.id, date: date)),
        ),
      ),
      data: (blocks) {
        if (blocks.isEmpty) {
          return EmptyState(
            icon: Icons.event_available_outlined,
            title: 'No blocks yet for ${group.name}',
            message:
                'Tap "+ Block" to add the first one. You set the time '
                "range — there's no fixed grid.",
          );
        }
        // Show the "Cover lead" strip when there's at least one
        // block with a planned lead (otherwise there's nothing to
        // cover, and the affordance is just noise).
        final hasAnyLead = blocks.any(
          (b) => b.leadMemberId != null && b.leadMemberId!.isNotEmpty,
        );
        final showCover = _isToday && hasAnyLead;
        return Column(
          children: [
            if (showCover)
              _CoverLeadStrip(
                groupId: group.id,
                groupName: group.name,
                date: date,
                anyCovered: blocks
                    .any((b) => b.leadSubstituteMemberId != null),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: blocks.length,
                itemBuilder: (_, i) {
                  final b = blocks[i];
                  final activity = b.activityId == null
                      ? null
                      : activities
                          .where((a) => a.id == b.activityId)
                          .firstOrNull;
                  final loc = b.locationOverrideId == null
                      ? null
                      : locations
                          .where((l) => l.id == b.locationOverrideId)
                          .firstOrNull;
                  return _BlockTile(
                    block: b,
                    activity: activity,
                    location: loc,
                    onTap: () => _openBlockSheet(
                      context,
                      ref,
                      groupId: group.id,
                      date: DateTime.parse(b.startAt).toLocal(),
                      defaultStart: DateTime.parse(b.startAt).toLocal(),
                      existingBlocks: blocks,
                      existing: b,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "Someone called out — pick a sub" entry point. Lives above the
/// blocks list on today's tab only. The bottom sheet does the
/// heavy lifting (one row per planned lead, with a count badge and
/// either a Cover or Restore button).
class _CoverLeadStrip extends StatelessWidget {
  const _CoverLeadStrip({
    required this.groupId,
    required this.groupName,
    required this.date,
    required this.anyCovered,
  });

  final String groupId;
  final String groupName;
  final String date;

  /// When at least one lead is already covered, the strip swaps
  /// to a slightly louder colour so the director can see at a
  /// glance that today is mid-handoff.
  final bool anyCovered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: anyCovered
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => SubstituteLeadSheet.show(
            context,
            groupId: groupId,
            groupName: groupName,
            date: date,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  anyCovered
                      ? Icons.swap_horiz
                      : Icons.person_off_outlined,
                  size: 18,
                  color: anyCovered
                      ? scheme.onTertiaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    anyCovered
                        ? "Someone's covering a lead today"
                        : "Cover today's lead",
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: anyCovered
                          ? scheme.onTertiaryContainer
                          : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: anyCovered
                      ? scheme.onTertiaryContainer
                          .withValues(alpha: 0.7)
                      : scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.block,
    required this.activity,
    required this.location,
    required this.onTap,
  });

  final ScheduleBlock block;
  final Activity? activity;
  final Location? location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = DateTime.parse(block.startAt).toLocal();
    final end = DateTime.parse(block.endAt).toLocal();
    final timeLabel = '${_t(start)} – ${_t(end)}';

    final isField = block.kind == 'field_trip';
    final isBreak = block.kind == 'break';
    final title = activity?.name ?? (isBreak ? 'Break' : block.notes ?? '—');

    final container = isField
        ? scheme.tertiaryContainer
        : (isBreak
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerHighest);
    final onContainer = isField
        ? scheme.onTertiaryContainer
        : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Material(
        color: container,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isField
                      ? Icons.directions_bus_outlined
                      : isBreak
                          ? Icons.local_cafe_outlined
                          : Icons.local_activity_outlined,
                  color: onContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onContainer.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: onContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (location != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          location!.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onContainer.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      if (block.notes != null &&
                          block.notes!.isNotEmpty &&
                          activity != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          block.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onContainer.withValues(alpha: 0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: onContainer.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _t(DateTime when) {
    final h = when.hour.toString().padLeft(2, '0');
    final m = when.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

Future<void> _openBlockSheet(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
  required DateTime date,
  required DateTime defaultStart,
  required List<ScheduleBlock> existingBlocks,
  ScheduleBlock? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => BlockEditSheet(
      groupId: groupId,
      defaultStart: defaultStart,
      existing: existing,
    ),
  );
}
