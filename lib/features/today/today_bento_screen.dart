import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/live_session/live_session_banner.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The **bento dashboard** home — the grid-navigation experiment. Same Today
/// providers (now/next lead, captures, tasks, rooms, this-week world), re-laid
/// out as modular tiles sized by importance, re-packing across phone / tablet /
/// desktop from one [BentoGrid]. Opt-in via Settings → Preferences
/// (`bentoHomeProvider`); the classic Today scroll is one tap away and never
/// deleted.
///
/// Staff-only — `_SignedInHome` already routes guardians to the family Today
/// before this can render.
class TodayBentoScreen extends ConsumerWidget {
  const TodayBentoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final labels = ref.watch(verticalLabelsProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return EdgeScaffold(
      showBack: false,
      actions: [
        if (groupsAsync.value?.isNotEmpty ?? false)
          PrimaryActionButton(
            tooltip: 'Capture',
            icon: Icons.bolt_outlined,
            onPressed: () => context.push('/captures/new'),
          ),
        const SyncStatusIndicator(),
      ],
      body: groupsAsync.when(
        loading: () => const LoadingSlot(variant: LoadingVariant.cards),
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
          return _BentoBody(viewer: viewer, groups: groups);
        },
      ),
    );
  }
}

class _BentoBody extends ConsumerWidget {
  const _BentoBody({required this.viewer, required this.groups});

  final Viewer viewer;
  final List<Group> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = viewer.space;

    final tiles = <BentoTile>[
      // Hero (wide, 2 rows) + Rooms (2 rows) fill the tall top run; the three
      // short tiles fill the run below. Spans omit args that match BentoSpan's
      // defaults (phone 2 / tablet 2 / desktop 2 / rows 1).
      const BentoTile(
        id: 'now-next',
        span: BentoSpan(tablet: 4, desktop: 4, rows: 2),
        child: _NowNextModule(),
      ),
      BentoTile(
        id: 'rooms',
        span: const BentoSpan(tablet: 4, rows: 2),
        child: _RoomsModule(groups: groups),
      ),
      const BentoTile(
        id: 'captures',
        span: BentoSpan(phone: 1),
        child: _CapturesModule(),
      ),
      const BentoTile(
        id: 'tasks',
        span: BentoSpan(phone: 1),
        child: _TasksModule(),
      ),
      const BentoTile(
        id: 'this-week',
        span: BentoSpan(tablet: 4),
        child: _ThisWeekModule(),
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContentHeader(
              title: space?.name ?? 'Today',
              subtitle: _greetingLine(),
            ),
            const LiveSessionBanner(),
            BentoGrid(tiles: tiles),
          ],
        ),
      ),
    );
  }

  static final DateFormat _dayFmt = DateFormat.yMMMMEEEEd();

  String _greetingLine() {
    final greeting = greetingForTime(DateTime.now());
    final dayLabel = _dayFmt.format(DateTime.now());
    final name = viewer.member?.displayName ?? '';
    if (name.isEmpty) return '$greeting · $dayLabel';
    return '$greeting, $name · $dayLabel';
  }
}

/// A themed bento tile — flat Material, rounded, tappable, with a foreground
/// colour every child text inherits via [DefaultTextStyle]. No hardcoded
/// colours: callers pass [background] / [foreground] from the ColorScheme or a
/// content-driven accent run through [AppColors].
class _BentoModule extends StatelessWidget {
  const _BentoModule({
    required this.background,
    required this.foreground,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });

  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small rounded chip holding the module's leading icon.
class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18),
    );
  }
}

/// The hero: "what matters right now" + the move it calls for, from
/// [contextLeadProvider] (the same source the classic Today's _RightNowCard
/// uses). Calm fallback when nothing's pending.
class _NowNextModule extends ConsumerWidget {
  const _NowNextModule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lead = ref.watch(contextLeadProvider);

    if (lead == null) {
      return _BentoModule(
        background: scheme.surfaceContainerHigh,
        foreground: scheme.onSurface,
        onTap: () => context.push('/schedule'),
        semanticLabel: 'Schedule',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ModuleIcon(
                  icon: Icons.wb_sunny_outlined,
                  tint: scheme.surfaceContainerHighest,
                ),
                const SizedBox(width: 10),
                Text('Now', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing needs you right now',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Open the schedule to see what’s next.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final (
      Color bg,
      Color fg,
      Color accent,
      Color onAccent,
    ) = switch (lead.tone) {
      ContextTone.go => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.primary,
        scheme.onPrimary,
      ),
      ContextTone.trip => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        scheme.tertiary,
        scheme.onTertiary,
      ),
      ContextTone.pickup => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        scheme.secondary,
        scheme.onSecondary,
      ),
      ContextTone.calm => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        scheme.primary,
        scheme.onPrimary,
      ),
    };

    return _BentoModule(
      background: bg,
      foreground: fg,
      onTap: () => context.push(lead.primary.route),
      semanticLabel: '${lead.eyebrow}: ${lead.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ModuleIcon(icon: lead.icon, tint: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lead.eyebrow.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lead.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            lead.line,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fg.withValues(alpha: 0.85),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _MovePill(
              label: lead.primary.label,
              icon: lead.primary.icon,
              background: accent,
              foreground: onAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// The primary-move pill inside the hero (filled with the lead's accent).
class _MovePill extends StatelessWidget {
  const _MovePill({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// A paper-toned count tile (Captures / Tasks): icon + title + a big count and
/// one-line caption, with a badge when there's anything pending.
class _CountModule extends StatelessWidget {
  const _CountModule({
    required this.icon,
    required this.title,
    required this.count,
    required this.caption,
    required this.route,
  });

  final IconData icon;
  final String title;
  final int count;
  final String caption;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _BentoModule(
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurface,
      onTap: () => context.push(route),
      semanticLabel: '$title, $count $caption',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ModuleIcon(icon: icon, tint: scheme.surfaceContainerLow),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$count',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count == 0 ? 'All clear' : caption,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapturesModule extends ConsumerWidget {
  const _CapturesModule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(openCapturesProvider).value?.length ?? 0;
    return _CountModule(
      icon: Icons.inbox_outlined,
      title: 'Captures',
      count: count,
      caption: count == 1 ? '1 to triage' : '$count to triage',
      route: '/captures',
    );
  }
}

class _TasksModule extends ConsumerWidget {
  const _TasksModule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(openTasksProvider).value?.length ?? 0;
    return _CountModule(
      icon: Icons.checklist_outlined,
      title: 'Tasks',
      count: count,
      caption: count == 1 ? '1 open' : '$count open',
      route: '/tasks',
    );
  }
}

/// The rooms module — a compact list of cohorts with a status dot + the
/// marked-of-total headline, each row tapping into that cohort. The bento
/// equivalent of Today's room cards, sized to a tile.
class _RoomsModule extends ConsumerWidget {
  const _RoomsModule({required this.groups});

  final List<Group> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labels = ref.watch(verticalLabelsProvider);
    // Cap the visible rows so the tile stays a tile; the rest are reachable
    // by tapping through.
    final visible = groups.length > 4 ? groups.sublist(0, 4) : groups;

    return _BentoModule(
      background: scheme.surfaceContainerHigh,
      foreground: scheme.onSurface,
      onTap: () => context.push('/groups/${groups.first.id}'),
      semanticLabel: '${groups.length} ${labels.groupPlural.toLowerCase()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ModuleIcon(
                icon: Icons.meeting_room_outlined,
                tint: scheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  labels.groupPlural,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${groups.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final g in visible) _RoomRow(group: g),
          if (groups.length > visible.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+${groups.length - visible.length} more',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomRow extends ConsumerWidget {
  const _RoomRow({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(groupDayStateProvider(group)).value;
    final dot = state == null ? StatusDotKind.neutral : _dotKindFor(state);
    final count = (state == null || state.totalSubjects == 0)
        ? null
        : '${state.markedCount}/${state.totalSubjects}';

    return Semantics(
      button: true,
      label: count == null ? group.name : '${group.name}, $count marked',
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          unawaited(context.push('/groups/${group.id}'));
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              StatusDot(kind: dot),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.name,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null)
                Text(
                  count,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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

/// The "this week" tile — watches the curriculum world itself (so the parent
/// body doesn't rebuild on schedule ticks) and shows the world or, before a
/// journey is live, the activities fallback.
class _ThisWeekModule extends ConsumerWidget {
  const _ThisWeekModule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(currentWorldProvider);
    return world == null
        ? const _ActivitiesModule()
        : _WorldModule(world: world);
  }
}

/// "This week" — the live curriculum world, tinted with its own accent colour
/// (content-driven; foreground picked for contrast via [AppColors.onAccent]).
class _WorldModule extends StatelessWidget {
  const _WorldModule({required this.world});

  final CurriculumWorld world;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = AppColors.onAccent(world.color);
    return _BentoModule(
      background: world.color,
      foreground: fg,
      onTap: () => context.push('/this-week'),
      semanticLabel: 'This week, week ${world.week}, ${world.name}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(world.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Week ${world.week}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            world.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '“${world.question}”',
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg.withValues(alpha: 0.85),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Fallback for "This week" before a journey is live — points at the activity
/// library so the slot still leads somewhere useful.
class _ActivitiesModule extends StatelessWidget {
  const _ActivitiesModule();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _BentoModule(
      background: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
      onTap: () => context.push('/thinking'),
      semanticLabel: 'Activities',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ModuleIcon(icon: Icons.apps_outlined, tint: scheme.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Activities',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Games to play with the room',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onTertiaryContainer.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
