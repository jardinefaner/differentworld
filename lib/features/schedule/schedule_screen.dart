import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/curricula/photo_curriculum.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/widgets/substitute_lead_sheet.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/semantics/noun_scope.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/inline_editable_text.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// `/schedule` — staff-side schedule for one date. Cohort tabs across
/// the top; each tab shows the chronological list of blocks for that
/// cohort. The "+" FAB authors a new block in the current cohort.
///
/// Block boundaries are per-row (no fixed grid). Teachers set start
/// and end times directly when authoring.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key, this.initialDate});

  /// Optional fallback used only when the URL has no `?date=` param
  /// (e.g. deep-linking from a notification). The URL is the
  /// canonical source.
  final DateTime? initialDate;

  /// Query-string parameter for the active day. Stored as `YYYY-MM-DD`
  /// so a bookmark / refresh / share keeps the schedule pinned to the
  /// same day. Defaults to today when missing or unparseable.
  static const _dateParam = 'date';

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen>
    with TickerProviderStateMixin {
  TabController? _tabs;
  int _activeTabIndex = 0;

  /// Guards the formless `+` against a fat-finger double/triple tap
  /// spawning two blank blocks. Held from the tap until the (local-first,
  /// sub-frame) create resolves; further taps after that create more
  /// blocks on purpose.
  bool _creatingBlock = false;

  /// The frame registry for this screen (docs/SEMANTIC_GRAPH.md). Every
  /// NounScope under the body registers here, so a structural UiFrame of
  /// the schedule — where each block sits, in what state — can be
  /// captured without a screenshot.
  late final NounRegistry _registry = NounRegistry();

  /// Today's date — used as the fallback when the URL has nothing.
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Reads the active day out of the URL (`?date=YYYY-MM-DD`). Falls
  /// back to the widget's initialDate, then to today. Called from
  /// `build` — the URL is the source of truth, no `setState` needed
  /// when the user picks a different day.
  DateTime _dateFromUri(BuildContext context) {
    final raw = GoRouterState.of(
      context,
    ).uri.queryParameters[ScheduleScreen._dateParam];
    if (raw != null && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return widget.initialDate == null
        ? _today
        : DateTime(
            widget.initialDate!.year,
            widget.initialDate!.month,
            widget.initialDate!.day,
          );
  }

  void _setDate(BuildContext context, DateTime next) {
    // `replace` so back doesn't traverse the date picker — the user
    // expects back to exit the screen.
    context.replace(
      '/schedule?${ScheduleScreen._dateParam}=${dateKey(next)}',
    );
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

  bool _isToday(DateTime date) {
    final t = _today;
    return date.year == t.year && date.month == t.month && date.day == t.day;
  }

  String _dateLabel(DateTime date) {
    final delta = date.difference(_today).inDays;
    if (delta == 0) return 'Today';
    if (delta == 1) return 'Tomorrow';
    if (delta == -1) return 'Yesterday';
    return DateFormat.yMMMMEEEEd().format(date);
  }

  Future<void> _pickDate(BuildContext context, DateTime date) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && context.mounted) {
      _setDate(context, DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _dateFromUri(context);
    final dateIso = isoDateLocal(date);
    final groupsAsync = ref.watch(groupsProvider);
    final groups = groupsAsync.value ?? const <Group>[];
    final tabs = groups.isEmpty ? null : _ensureTabController(groups.length);

    // '+ Block' is a write — only viewers with canManageSchedule can
    // author blocks. Hide the chrome action for everyone else
    // (matches the hide-don't-disable rule) so a teacher without the
    // cap doesn't tap into a sheet they can't save from.
    final viewer = ref.watch(viewerProvider);
    final canEditSchedule = viewer.canManageSchedule || viewer.canManageSpace;
    return NounRegistryScope(
      registry: _registry,
      child: EdgeScaffold(
        showBack: false,
        actions: (groups.isEmpty || !canEditSchedule)
            ? const <Widget>[]
            : [
                // Wave 154: shortcut to the weekly-template author.
                IconButton(
                  icon: const Icon(Icons.event_repeat),
                  tooltip: 'Weekly template',
                  onPressed: () => context.push('/schedule/template'),
                ),
                // The day-template builder — shape the day once, drop it
                // onto a date.
                IconButton(
                  icon: const Icon(Icons.view_timeline_outlined),
                  tooltip: 'Day templates',
                  onPressed: () => context.push('/schedule/day-templates'),
                ),
                PrimaryActionButton(
                  tooltip: 'New block',
                  icon: Icons.add,
                  onPressed: () {
                    final cohort =
                        groups[_activeTabIndex.clamp(
                          0,
                          groups.length - 1,
                        )];
                    unawaited(_createBlockFormless(cohort, date));
                  },
                ),
              ],
        body: groupsAsync.when(
          loading: () => const LoadingSlot(),
          error: (err, stack) {
            // Wave 165.1 — surface the actual cause so we can tell
            // "PowerSync hasn't synced yet" from "Drift query failed
            // because the local schema is missing a column" from
            // "guardian viewer hit /schedule which isn't gated."
            if (kDebugMode) {
              debugPrint('[schedule] groupsProvider failed: $err');
              debugPrint('[schedule] stack: $stack');
            }
            return ErrorState(
              title: 'Could not load schedule',
              detail: '$err',
              onRetry: () => ref.invalidate(groupsProvider),
            );
          },
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
                    subtitle: _dateLabel(date),
                    bottomGap: 8,
                  ),
                ),
                _DateScrubber(
                  label: _dateLabel(date),
                  isToday: _isToday(date),
                  onPrev: () =>
                      _setDate(context, date.subtract(const Duration(days: 1))),
                  onNext: () =>
                      _setDate(context, date.add(const Duration(days: 1))),
                  onPickDate: () => _pickDate(context, date),
                  onJumpToday: () => _setDate(context, _today),
                ),
                // Wave 158: events for this date appear as a banner
                // above the cohort tabs. Built as a Consumer so a
                // freshly-created event renders without rebuilding
                // the parent. Drops silently when the day has none.
                _EventBanner(date: dateKey(date)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // The schedule matrix (docs/PLATFORM_RUBRIC.md): on a
                      // wide screen a director planning the day sees EVERY
                      // cohort at once as side-by-side columns, instead of
                      // flipping one-at-a-time tabs. Phones — and narrow
                      // windows with many cohorts (columns would be too
                      // thin) — keep the tabs. Reuses _CohortDay verbatim,
                      // so blocks / conflicts / cover-lead match exactly.
                      const minTotalWidth = 720.0;
                      const minColumnWidth = 300.0;
                      final showMatrix = gs.length > 1 &&
                          constraints.maxWidth >= minTotalWidth &&
                          constraints.maxWidth / gs.length >= minColumnWidth;
                      if (showMatrix) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < gs.length; i++) ...[
                              if (i > 0) const VerticalDivider(width: 1),
                              Expanded(
                                // Keyed by cohort so a roster change can't
                                // mis-route a column's provider subscription.
                                key: ValueKey('matrix-col-${gs[i].id}'),
                                child: _CohortColumn(
                                  group: gs[i],
                                  date: dateIso,
                                ),
                              ),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: [
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
                                  _CohortDay(group: g, date: dateIso),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Next round half-hour from now (or 9 a.m. on a future date). The
  /// scheduler can override; this just seeds the time picker so the
  /// teacher doesn't start at "12:00 a.m." by default.
  /// Formless create (option B): make the block NOW at a smart default
  /// time with an empty title. It appears as a card in the cohort
  /// column; tap its name to fill it in. The block is real immediately
  /// (local-first), so a mis-tap or a "phone rang, walked away" would
  /// otherwise leave a permanent blank block — the Undo snackbar gives
  /// that a one-tap escape hatch. [_creatingBlock] debounces a
  /// double-tap so a single intent can't spawn two blanks.
  Future<void> _createBlockFormless(Group cohort, DateTime date) async {
    if (_creatingBlock) return;
    _creatingBlock = true;
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(scheduleActionsProvider);
    final start = _defaultStartTime(date);
    unawaited(HapticFeedback.selectionClick());
    try {
      final id = await actions.create(
        groupId: cohort.id,
        startAt: start,
        endAt: start.add(const Duration(minutes: 30)),
      );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Block added — tap its name to fill it in'),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => unawaited(actions.delete_(id)),
            ),
          ),
        );
    } finally {
      _creatingBlock = false;
    }
  }

  DateTime _defaultStartTime(DateTime date) {
    final now = DateTime.now();
    if (now.year != date.year ||
        now.month != date.month ||
        now.day != date.day) {
      return DateTime(date.year, date.month, date.day, 9);
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
                      // Flexible + ellipsis — a long weekday-month-day
                      // label ("Wednesday, November 25, 2026") was
                      // overflowing horizontally on phone (RenderFlex
                      // overflow caught in /tmp/dw-pixel.log, Wave 66).
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
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

/// One cohort's column in the wide-screen schedule matrix — a cohort-name
/// header over that cohort's day. Reuses [_CohortDay] so block rendering,
/// conflict chips, and the cover-lead strip match the phone tab view
/// exactly; the matrix is purely a wide-screen arrangement of the same
/// per-cohort view side by side (docs/PLATFORM_RUBRIC.md).
class _CohortColumn extends StatelessWidget {
  const _CohortColumn({required this.group, required this.date});

  final Group group;
  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            group.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(child: _CohortDay(group: group, date: date)),
      ],
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
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];
    // Wave 156: every block in the program for this date + every
    // group, so we can flag rooms that two cohorts share at
    // overlapping times. Warning chip only — sometimes the director
    // intentionally schedules shared rooms (combined-cohort outdoor
    // play).
    final dayBlocks =
        ref.watch(scheduleDayProvider(date)).value ?? const <ScheduleBlock>[];
    final allGroups = ref.watch(groupsProvider).value ?? const <Group>[];
    final groupNameById = {for (final g in allGroups) g.id: g.name};
    final viewer = ref.watch(viewerProvider);
    final canEdit = viewer.canManageSchedule || viewer.canManageSpace;

    return blocksAsync.when(
      loading: () => const LoadingSlot(),
      error: (err, stack) {
        if (kDebugMode) {
          debugPrint(
            '[schedule] scheduleDayForGroupProvider(${group.id}, $date) '
            'failed: $err',
          );
          debugPrint('[schedule] stack: $stack');
        }
        return ErrorState(
          title: "Couldn't load this cohort's schedule",
          detail: '$err',
          onRetry: () => ref.invalidate(
            scheduleDayForGroupProvider((groupId: group.id, date: date)),
          ),
        );
      },
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
                anyCovered: blocks.any((b) => b.leadSubstituteMemberId != null),
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
                  // Wave 156: effective location = override OR
                  // activity default. Conflict = same effective
                  // location, different cohort, overlapping time.
                  final conflictGroupNames = _conflictsForBlock(
                    block: b,
                    activity: activity,
                    dayBlocks: dayBlocks,
                    activities: activities,
                    groupNameById: groupNameById,
                  );
                  return _BlockTile(
                    block: b,
                    activity: activity,
                    location: loc,
                    editable: canEdit,
                    conflictWith: conflictGroupNames,
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
                  anyCovered ? Icons.swap_horiz : Icons.person_off_outlined,
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
                      ? scheme.onTertiaryContainer.withValues(alpha: 0.7)
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

/// Wave 156: which OTHER cohort group-names this block conflicts with
/// at this date+time, by sharing the effective location (override on
/// the block OR the activity's default). Empty list = no conflict.
///
/// Effective overlap uses half-open intervals — block A from 14:00 to
/// 15:00 doesn't conflict with block B from 15:00 to 16:00.
List<String> _conflictsForBlock({
  required ScheduleBlock block,
  required Activity? activity,
  required List<ScheduleBlock> dayBlocks,
  required List<Activity> activities,
  required Map<String, String> groupNameById,
}) {
  final myLocId = block.locationOverrideId ?? activity?.defaultLocationId;
  if (myLocId == null) return const [];
  final myStart = DateTime.parse(block.startAt);
  final myEnd = DateTime.parse(block.endAt);
  final out = <String>[];
  for (final other in dayBlocks) {
    if (other.id == block.id) continue;
    if (other.groupId == block.groupId) continue;
    final otherActivity = other.activityId == null
        ? null
        : activities.where((a) => a.id == other.activityId).firstOrNull;
    final otherLocId =
        other.locationOverrideId ?? otherActivity?.defaultLocationId;
    if (otherLocId != myLocId) continue;
    final otherStart = DateTime.parse(other.startAt);
    final otherEnd = DateTime.parse(other.endAt);
    // Half-open overlap: a starts before b ends AND b starts before
    // a ends.
    if (myStart.isBefore(otherEnd) && otherStart.isBefore(myEnd)) {
      final name = groupNameById[other.groupId];
      if (name != null && !out.contains(name)) out.add(name);
    }
  }
  return out;
}

class _BlockTile extends ConsumerWidget {
  const _BlockTile({
    required this.block,
    required this.activity,
    required this.location,
    required this.onTap,
    this.editable = false,
    this.conflictWith = const [],
  });

  final ScheduleBlock block;
  final Activity? activity;
  final Location? location;
  final VoidCallback onTap;

  /// When true the block's name is tap-to-edit inline (the formless
  /// create / rename — option B). False → plain read-only text.
  final bool editable;

  /// Wave 156: names of other cohorts sharing this block's room at
  /// overlapping times. Renders as an amber chip; never blocks the
  /// block from saving.
  final List<String> conflictWith;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = DateTime.parse(block.startAt).toLocal();
    final end = DateTime.parse(block.endAt).toLocal();
    final timeLabel = '${_t(start)} – ${_t(end)}';

    final isField = block.kind == BlockKind.fieldTrip;
    final isBreak = block.kind == BlockKind.breakBlock;
    // Wave 165: when a block is linked to a curriculum session, the
    // session title wins over the (likely-empty) activity field. The
    // session badge below tells the staff this isn't an ad-hoc
    // activity, it's part of a structured program.
    final curriculumSession = block.curriculumSessionSlug == null
        ? null
        : findSessionBySlug(block.curriculumSessionSlug!);
    // Free-text title wins (the formless name you typed); else fall back
    // to the linked session / activity; else empty so the inline field
    // shows its "Name this block" placeholder for a bare new card.
    final blockTitle = block.title?.trim() ?? '';
    final title = blockTitle.isNotEmpty
        ? blockTitle
        : (curriculumSession?.title ??
              activity?.name ??
              (isBreak ? 'Break' : ''));

    final container = isField
        ? scheme.tertiaryContainer
        : (isBreak
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerHighest);
    final onContainer = isField ? scheme.onTertiaryContainer : scheme.onSurface;

    // Wave 155: dim skipped / cancelled blocks so the today view
    // visually fades them while still showing they were on the
    // plan. The director / family can read the reason in the edit
    // sheet.
    final isSkipped =
        block.status == BlockStatus.skipped ||
        block.status == BlockStatus.cancelled;
    return NounScope(
      noun: 'ScheduleBlock',
      id: block.id,
      actions: <String>['tap', if (editable) 'edit'],
      state: <String, Object?>{
        'kind': block.kind,
        'named': blockTitle.isNotEmpty,
        if (isSkipped) 'skipped': true,
        if (conflictWith.isNotEmpty) 'conflict': true,
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Opacity(
          opacity: isSkipped ? 0.55 : 1.0,
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
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          InlineEditableText(
                            value: title,
                            placeholder: 'Name this block',
                            editable: editable,
                            clearable: false,
                            semanticLabel: 'Block name',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: onContainer,
                              fontWeight: FontWeight.w600,
                            ),
                            onCommit: (text) => ref
                                .read(scheduleActionsProvider)
                                .update_(id: block.id, title: text),
                          ),
                          if (curriculumSession != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: curriculumSession.color.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.photo_camera_outlined,
                                    size: 13,
                                    color: curriculumSession.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Through My Eyes · '
                                    'S${curriculumSession.number}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: curriculumSession.color,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (location != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              location!.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: onContainer.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                          if (isField) ...[
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: () =>
                                  context.push('/trips/${block.id}'),
                              icon: const Icon(
                                Icons.fact_check_outlined,
                                size: 16,
                              ),
                              label: const Text('Trip details'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                minimumSize: const Size(0, 28),
                              ),
                            ),
                          ],
                          if (conflictWith.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            // Wave 156: warning chip. Director sometimes
                            // wants this (combined-cohort outdoor) so we
                            // never block — just surface visibly.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      conflictWith.length == 1
                                          ? 'Shared room with ${conflictWith.first}'
                                          : 'Shared room with '
                                                '${conflictWith.join(", ")}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: onContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
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
        ),
      ),
    );
  }

  static String _t(DateTime when) => timeOfDay(when);
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
  // Push the block-edit route (Wave 26). Args ride via go_router
  // `extra`. Helper signature kept for source compat with the
  // pre-route call sites — `date` + `existingBlocks` are unused
  // by the screen itself.
  return context.push<void>(
    '/schedule/block',
    extra: (
      groupId: groupId,
      defaultStart: defaultStart,
      existing: existing,
      prefillCurriculumSlug: null,
    ),
  );
}

/// Wave 158: banner showing one-off events for the current date.
/// Renders as a colored card above the cohort tabs; tap-to-delete
/// for now (full event-detail editor lands as a follow-up).
class _EventBanner extends ConsumerWidget {
  const _EventBanner({required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsForDateProvider(date));
    final events = eventsAsync.value ?? const <Event>[];
    if (events.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color:
                    _parseColor(e.color) ??
                    theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _confirmDelete(context, ref, e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          e.mode == 'closes_day'
                              ? Icons.event_busy_outlined
                              : e.mode == 'replaces'
                              ? Icons.event_repeat_outlined
                              : Icons.celebration_outlined,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (e.description != null &&
                                  e.description!.isNotEmpty)
                                Text(
                                  e.description!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme
                                        .colorScheme
                                        .onSecondaryContainer
                                        .withValues(alpha: 0.85),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Event e,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.title),
        content: const Text('Remove this event from the schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(eventActionsProvider).delete_(e.id);
    }
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value).withValues(alpha: 0.85);
  }
}
