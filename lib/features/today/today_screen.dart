import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/certifications/certifications_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/widgets/leading_today_card.dart';
import 'package:differentworld/features/schedule/widgets/now_next_strip.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/features/today/widgets/quick_actions.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/main_drawer.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/skeleton.dart';
import 'package:differentworld/shared/widgets/status_dot.dart';
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
  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final labels = ref.watch(verticalLabelsProvider);
    final member = viewer.member;
    final space = viewer.space;
    final groupsAsync = ref.watch(groupsProvider);

    return EdgeScaffold(
      // Today is a home page → no back button, just the hamburger.
      // Search affordance is the global one injected by EdgeScaffold —
      // the previous in-place inline search mode is gone; everything
      // routes through the global omnibox now.
      showBack: false,
      drawer: const MainDrawer(),
      actions: [
        // Primary verb on Today is "Capture" — what used to be the
        // bottom-right FAB lives here so the bottom of the screen is
        // free for the omnibox bar.
        if (groupsAsync.value?.isNotEmpty ?? false)
          PrimaryActionButton(
            tooltip: 'Capture',
            icon: Icons.bolt_outlined,
            onPressed: () => context.push('/captures/new'),
          ),
        const SyncStatusIndicator(),
      ],
      body: groupsAsync.when(
        loading: () =>
            const LoadingSlot(variant: LoadingVariant.cards),
        error: (_, _) => ErrorState(
          title: 'Could not load today',
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            final groupLower = labels.group.toLowerCase();
            final groupsLower = labels.groupPlural.toLowerCase();
            return EmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'No $groupsLower yet',
              message: viewer.canManageSpace
                  ? 'Add your first $groupLower to start taking '
                      '${labels.attendanceNoun.toLowerCase()} and '
                      'logging the day.'
                  : 'Your director will set up $groupsLower here. '
                      'Check back later.',
              action: viewer.canManageSpace
                  ? FilledButton.icon(
                      onPressed: () => context.push('/groups/new'),
                      icon: const Icon(Icons.add),
                      label: Text('Add $groupLower'),
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
      // FAB removed — Capture is now the primary action in the
      // top-right pill (see actions above). The bottom of the screen
      // is reserved for the omnibox bar.
    );
  }
}

/// Top-of-Today card that launches the Morning Checklist. This is the
/// primary daily-use entry point — one scroll across every classroom.
class _ChecklistCallToAction extends ConsumerWidget {
  const _ChecklistCallToAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labels = ref.watch(verticalLabelsProvider);
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
                      'One scroll, every ${labels.group.toLowerCase()}, '
                      'mark everyone in.',
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

class _TodayBody extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(verticalLabelsProvider);
    // Flag-first subtitle: if any cohort has at least one flagged
    // subject, pivot the greeting line to the action-state instead of
    // a cheery hello. Calmer mornings still get the warm greeting.
    var totalFlags = 0;
    var roomsWithFlags = 0;
    for (final g in groups) {
      final state = ref.watch(groupDayStateProvider(g)).value;
      if (state != null && state.hasFlag) {
        totalFlags += state.flagCount;
        roomsWithFlags += 1;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = FormFactor.fromWidth(constraints.maxWidth);
        final horiz = formFactor.isExpanded ? 48.0 : 16.0;

        return ListView(
          // Horizontal-only padding; shell handles top + bottom chrome
          // reservation so the list ends above the omnibox naturally.
          padding: EdgeInsets.fromLTRB(horiz, 0, horiz, 24),
          children: [
            ContentHeader(
              title: space?.name ?? 'Today',
              subtitle: _subtitleLine(
                member: member,
                totalFlags: totalFlags,
                roomsWithFlags: roomsWithFlags,
                labels: labels,
              ),
              subtitleColor: totalFlags > 0
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
            // Specialist / substitute identity strip — answers the
            // Coach Sam audit finding ("no UI surface tells Sam what
            // they are"). Renders nothing for director / lead_teacher
            // / teacher / guardian because context already makes the
            // role obvious. Tap → Roles page so Sam can see what their
            // role can do.
            const _IdentityStrip(),
            // Morning Checklist is only useful to staff who can
            // actually mark daily routines — hide for read-only viewers.
            if (viewer.isDailyLogger) const _ChecklistCallToAction(),
            if (viewer.isDailyLogger) const SizedBox(height: 16),
            // "You're leading N blocks today" — renders nothing if
            // the signed-in member isn't a lead on any block today.
            // Naturally hides for non-staff and members with no
            // assignments.
            const LeadingTodayCard(),
            const SizedBox(height: 16),
            // Director's morning pulse — aggregates absent kids,
            // cohorts with substitute coverage today, and
            // expiring-soon certs into a single card. Renders
            // nothing when there's nothing to flag (the "all clear"
            // case doesn't need to consume scroll). Only directors
            // see this; non-directors hit the early-return.
            if (viewer.isDirector) ...[
              _DirectorPulseCard(groups: groups),
              const SizedBox(height: 16),
            ],
            // Upward loop made visible: the system surfaces one
            // question here when the data demands it; silent when
            // it doesn't. UX_DECISIONS §6 / framework upward loop.
            const TopInsightCard(),
            const SizedBox(height: 16),
            // Capability-aware one-tap launchpad. Hides itself when the
            // viewer has nothing to launch.
            const QuickActions(),
            const SizedBox(height: 24),
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

  static String _subtitleLine({
    required Member? member,
    required int totalFlags,
    required int roomsWithFlags,
    required VerticalLabels labels,
  }) {
    if (totalFlags > 0) {
      final subj =
          totalFlags == 1 ? labels.subject.toLowerCase() : labels.subjectPlural.toLowerCase();
      final verb = totalFlags == 1 ? 'needs' : 'need';
      if (roomsWithFlags == 1) {
        return '$totalFlags $subj $verb your attention';
      }
      return '$totalFlags $subj $verb your attention · across '
          '$roomsWithFlags ${labels.groupPlural.toLowerCase()}';
    }
    final greeting = greetingForTime(DateTime.now());
    final dayLabel = DateFormat.yMMMMEEEEd().format(DateTime.now());
    final name = member?.displayName ?? '';
    if (name.isEmpty) return '$greeting · $dayLabel';
    return '$greeting, $name · $dayLabel';
  }
}


/// Per-group card on the Today screen: name, today's attendance state,
/// quick action.
///
/// At-a-glance language is a *status dot* on the left: green (done),
/// amber (in progress), red (untouched / flag), neutral (empty). The
/// pills underneath act as the act-on detail; the dot alone is enough
/// to scan a 6-room list in a glance.
class _GroupTodayCard extends ConsumerWidget {
  const _GroupTodayCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stateAsync = ref.watch(groupDayStateProvider(group));

    final dotKind = stateAsync.value == null
        ? StatusDotKind.neutral
        : _dotKindFor(stateAsync.value!);

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
                  // Traffic-light scan affordance — the eye lands here
                  // first, before the room name. Glow ring when a kid
                  // is flagged so you find that one row in a list of N.
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: StatusDot(kind: dotKind),
                  ),
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
                        context.push('/groups/${group.id}/attendance'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // "Now / Next" schedule strip — tells the staff scanner
              // what the room is doing this very moment without having
              // to open the schedule editor. Renders nothing if the
              // cohort has no blocks today.
              NowNextStrip(groupId: group.id),
              const SizedBox(height: 12),
              stateAsync.when(
                // Shaped skeleton instead of a "Loading…" line — the
                // layout doesn't jump when the data lands.
                loading: () => const SkeletonShimmer(
                  child: Row(
                    children: [
                      SkeletonBox(width: 84, height: 22, radius: 11),
                      SizedBox(width: 8),
                      SkeletonBox(width: 64, height: 22, radius: 11),
                    ],
                  ),
                ),
                error: (_, _) => _StateLine(
                  text: 'Tap to retry.',
                  color: theme.colorScheme.error,
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

  static StatusDotKind _dotKindFor(GroupDayState s) {
    if (s.hasFlag) return StatusDotKind.needsAttention;
    if (s.totalSubjects == 0) return StatusDotKind.neutral;
    if (s.isComplete) return StatusDotKind.calm;
    if (s.markedCount == 0) return StatusDotKind.needsAttention;
    return StatusDotKind.progress;
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

/// Director's morning pulse — a single card surfacing the three
/// things a director typically checks first: who's absent, where
/// someone is covering, and what's about to expire.
///
/// **Renders nothing when there's nothing to flag.** "All clear" is
/// not a card; it's the absence of one. That keeps the rest of the
/// Today scroll calm on quiet mornings.
///
/// Reads three providers, none of them new:
/// * `groupDayStateProvider(g)` per group → sum absent counts
/// * `scheduleDayProvider(todayIso)` → cohorts with non-null
///   `leadSubstituteMemberId`, deduplicated by group
/// * `certsInSpaceProvider` → certs expiring in the next 30 days
///   (or already expired)
class _DirectorPulseCard extends ConsumerWidget {
  const _DirectorPulseCard({required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Absent across all cohorts today.
    var absent = 0;
    for (final g in groups) {
      final state = ref.watch(groupDayStateProvider(g)).value;
      if (state != null) {
        absent += state.counts[AttendanceStatus.absent] ?? 0;
      }
    }

    // Cohorts with a substitute covering today (deduped by group_id).
    final blocks =
        ref.watch(scheduleDayProvider(todayIso())).value ?? const <ScheduleBlock>[];
    final coveredGroupIds = <String>{};
    for (final b in blocks) {
      if (b.leadSubstituteMemberId != null &&
          b.leadSubstituteMemberId!.isNotEmpty) {
        coveredGroupIds.add(b.groupId);
      }
    }
    final substituteGroups = coveredGroupIds.length;

    // Certs expiring within 30 days OR already expired.
    final certs =
        ref.watch(certsInSpaceProvider).value ?? const <MemberCertification>[];
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 30));
    var expiring = 0;
    for (final c in certs) {
      final iso = c.expiresAt;
      if (iso == null || iso.isEmpty) continue;
      final exp = DateTime.tryParse(iso);
      if (exp == null) continue;
      if (exp.isBefore(cutoff)) expiring++;
    }

    // Nothing to flag → render nothing.
    if (absent == 0 && substituteGroups == 0 && expiring == 0) {
      return const SizedBox.shrink();
    }

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard_outlined,
                    size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  "Today's pulse",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (absent > 0)
              _PulseRow(
                icon: Icons.event_busy_outlined,
                tint: scheme.error,
                label: '$absent ${absent == 1 ? "kid" : "kids"} '
                    'absent today',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            if (substituteGroups > 0)
              _PulseRow(
                icon: Icons.person_add_alt_1,
                tint: scheme.tertiary,
                label: substituteGroups == 1
                    ? '1 cohort with a substitute covering today'
                    : '$substituteGroups cohorts with a substitute '
                        'covering today',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            if (expiring > 0)
              _PulseRow(
                icon: Icons.verified_outlined,
                tint: scheme.tertiary,
                label: '$expiring ${expiring == 1 ? "cert" : "certs"} '
                    'expiring in the next 30 days',
                onTap: () => Navigator.of(context).maybePop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _PulseRow extends StatelessWidget {
  const _PulseRow({
    required this.icon,
    required this.tint,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// "You are: …" strip on the Today header — answers the Coach Sam
/// audit finding from 2026-05-23. Renders only for the roles where
/// the position isn't obvious from the rest of the chrome:
///
///   * **Specialist** — Coach / Tutor / Reading Specialist, etc.
///     Their cohort scope is determined by group assignments, not
///     role label, so they need an explicit signal that "specialist"
///     is what they are.
///   * **Substitute** — limited default bundle (observe + attendance,
///     no schedule write, no pickup auth). Saying it on Today helps
///     Brianna understand why some affordances aren't there for her.
///
/// Directors / lead teachers / counselors / kitchen / guardians get
/// nothing — their context (the data they're looking at, the actions
/// they have access to) already implies their role. Adding a strip
/// for them would be chrome noise.
///
/// Tap → `/settings/roles` so the user can read what their role can
/// and can't do. The page is read-only; this is just helping them
/// orient.
class _IdentityStrip extends ConsumerWidget {
  const _IdentityStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (!viewer.isSpecialist && !viewer.isSubstitute) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSpecialist = viewer.isSpecialist;
    final hasSpecialty = isSpecialist && viewer.specialty != null;
    // Specialist with no specialty set → director hasn't picked one yet.
    // Soft-tinted "Tap to set" hint mirrors the team-list flag from
    // Wave 35 (specialist without specialty shown in tertiary tint).
    final needsSpecialty = isSpecialist && !hasSpecialty;
    final icon = isSpecialist
        ? Icons.school_outlined
        : Icons.event_busy_outlined;
    final label = isSpecialist
        ? (hasSpecialty
            ? 'You are: Specialist · ${viewer.specialtyLabel}'
            : 'You are: Specialist · specialty not set')
        : 'You are: Substitute today';
    final background = needsSpecialty
        ? scheme.tertiaryContainer.withValues(alpha: 0.45)
        : scheme.surfaceContainerHigh;
    final foreground = needsSpecialty
        ? scheme.onTertiaryContainer
        : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push('/settings/roles'));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: foreground.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
