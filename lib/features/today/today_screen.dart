import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/omnibox/omnibox_results.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/features/today/widgets/quick_actions.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/main_drawer.dart';
import 'package:differentworld/shared/widgets/search_bar_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Home screen: "what's happening today across my classrooms."
///
/// Stateful so it can host the inline search mode: tap the search
/// icon → top chrome transforms into a search input (hamburger + sync
/// fade out) → body stays the same until the first character, at
/// which point the body crossfades to the omnibox results list.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String _query = '';

  void _enterSearch() {
    setState(() => _searching = true);
  }

  void _exitSearch() {
    _searchCtrl.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final member = viewer.member;
    final space = viewer.space;
    final groupsAsync = ref.watch(groupsProvider);

    return EdgeScaffold(
      // In search mode the hamburger pill is replaced by the search bar
      // (drawer is still reachable via swipe-from-left). Out of search
      // mode the hamburger is shown via the drawer presence.
      showBack: false,
      drawer: const MainDrawer(),
      topOverlay: _searching
          ? SearchBarPill(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              onClose: _exitSearch,
            )
          : null,
      actions: _searching
          ? const <Widget>[]
          : [
              IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search),
                onPressed: _enterSearch,
              ),
              const SyncStatusIndicator(),
            ],
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _query.isEmpty
            ? KeyedSubtree(
                key: const ValueKey('today-content'),
                child: groupsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load today',
                  ),
                  data: (groups) {
                    if (groups.isEmpty) {
                      return EmptyState(
                        icon: Icons.meeting_room_outlined,
                        title: 'No classrooms yet',
                        message: viewer.canManageProgram
                            ? 'Add your first classroom to start taking '
                                'attendance and logging the day.'
                            : 'Your director will set up classrooms here. '
                                'Check back later.',
                        action: viewer.canManageProgram
                            ? FilledButton.icon(
                                onPressed: () =>
                                    context.push('/groups/new'),
                                icon: const Icon(Icons.add),
                                label: const Text('Add classroom'),
                              )
                            : null,
                      );
                    }
                    return _TodayBody(
                      member: member,
                      groups: groups,
                      space: space,
                      viewer: viewer,
                    );
                  },
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('search-results'),
                child: OmniboxResults(query: _query),
              ),
      ),
      floatingActionButton: (_searching || !viewer.canManageProgram)
          ? null
          : groupsAsync.maybeWhen(
              data: (groups) => groups.isEmpty
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => context.push('/groups/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Classroom'),
                    ),
              orElse: () => null,
            ),
    );
  }
}

/// Top-of-Today card that launches the Morning Checklist. This is the
/// primary daily-use entry point — one scroll across every classroom.
class _ChecklistCallToAction extends StatelessWidget {
  const _ChecklistCallToAction();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          unawaited(context.push('/checklist'));
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.task_alt,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Morning checklist',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'One scroll, every classroom, mark everyone in.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({
    required this.member,
    required this.groups,
    required this.space,
    required this.viewer,
  });

  final Member? member;
  final List<Group> groups;
  final Space? space;
  final Viewer viewer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = FormFactor.fromWidth(constraints.maxWidth);
        final horiz = formFactor.isExpanded ? 48.0 : 16.0;

        return ListView(
          // Horizontal-only padding; vertical comes from ContentHeader
          // (which builds in clearance for the floating chrome) and a
          // generous bottom slot so FAB doesn't cover the last card.
          padding: EdgeInsets.fromLTRB(horiz, 0, horiz, 96),
          children: [
            ContentHeader(
              title: space?.name ?? 'Today',
              subtitle: _greetingLine(member),
            ),
            // Morning Checklist is only useful to staff who can
            // actually mark daily routines — hide for read-only viewers.
            if (viewer.isDailyLogger) const _ChecklistCallToAction(),
            if (viewer.isDailyLogger) const SizedBox(height: 24)
            else const SizedBox(height: 8),
            // Capability-aware one-tap launchpad. Hides itself when the
            // viewer has nothing to launch.
            const QuickActions(),
            const SizedBox(height: 16),
            _SectionHeader(
              label: 'Your classrooms',
              count: groups.length,
            ),
            const SizedBox(height: 8),
            ...groups.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  // RepaintBoundary so an InkWell ripple / re-watch
                  // on one card doesn't repaint its siblings — each
                  // card watches its own per-group state.
                  child: RepaintBoundary(child: _GroupTodayCard(group: g)),
                )),
          ],
        );
      },
    );
  }

  static String _greetingLine(Member? member) {
    final greeting = greetingForTime(DateTime.now());
    final dayLabel = DateFormat.yMMMMEEEEd().format(DateTime.now());
    final name = member?.displayName ?? '';
    if (name.isEmpty) return '$greeting · $dayLabel';
    return '$greeting, $name · $dayLabel';
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
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          unawaited(context.push('/groups/${group.id}'));
        },
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.name,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Flag badge: there's at least one late /
                            // absent student today in this room.
                            stateAsync.maybeWhen(
                              data: (s) => s.hasFlag
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 6),
                                      child: _FlagBadge(count: s.flagCount),
                                    )
                                  : const SizedBox.shrink(),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
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
                        context.push('/groups/${group.id}/attendance'),
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
                data: (state) =>
                    _DayStateRow(state: state, groupId: group.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayStateRow extends StatelessWidget {
  const _DayStateRow({required this.state, required this.groupId});

  final GroupDayState state;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    void openUnmarked() {
      unawaited(HapticFeedback.selectionClick());
      unawaited(context.push('/groups/$groupId/attendance'));
    }

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
      return InkWell(
        onTap: openUnmarked,
        borderRadius: BorderRadius.circular(8),
        child: _StateLine(
          text: '${state.totalSubjects} students • none marked yet',
          color: scheme.error,
        ),
      );
    }

    // Mixed state: show breakdown. The "unmarked" pill is tappable —
    // jumps into the per-room attendance screen so the teacher can
    // finish the room without losing their place.
    final pieces = <Widget>[
      _StatusPill(
        status: null,
        label: '${state.unmarked} unmarked',
        color: scheme.error,
        onTap: openUnmarked,
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
    this.onTap,
  });

  final AttendanceStatus? status;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
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
    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: body,
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

/// Small amber capsule shown next to a classroom name when there's at
/// least one late / absent student today. Draws the eye for the
/// staff Today scan.
class _FlagBadge extends StatelessWidget {
  const _FlagBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 12, color: tint),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              color: tint,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
