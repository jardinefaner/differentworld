import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/skills.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/certifications/certifications_providers.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/features/launch/launch_readiness.dart';
import 'package:differentworld/features/live_session/live_session_banner.dart';
import 'package:differentworld/features/messages/messages_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/widgets/leading_today_card.dart';
import 'package:differentworld/features/schedule/widgets/now_next_strip.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/features/today/widgets/quick_actions.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:differentworld/shared/widgets/skeleton.dart';
import 'package:differentworld/shared/widgets/status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
                        color: theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        ),
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

/// Time-aware lead card: orients the whole Today screen to the day's
/// current phase and points to the surface that matters *right now* —
/// arrival → check-in, program → schedule, pickup → the roster. The
/// phase comes from the wall clock via [dayPhaseProvider]; this card
/// only *leads the eye* to surfaces that already exist — no new data
/// layer (docs/WORKFLOWS.md gap #1, wave 1). Hidden after hours.
/// "Ready to run?" — the pre-9:00 setup check. Director-only, and only while
/// a gating precondition is still unmet; vanishes the moment the day is ready.
class _ReadyToRunCard extends ConsumerWidget {
  const _ReadyToRunCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (!viewer.isDirector) return const SizedBox.shrink();
    final items = ref.watch(launchReadinessProvider);
    if (allReady(items)) return const SizedBox.shrink();
    final count = readyCount(items);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.primaryContainer,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push('/ready'));
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
                    Icons.rocket_launch_outlined,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to run?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${count.done} of ${count.total} set for tomorrow — '
                        'finish setup.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(
                                alpha: 0.8,
                              ),
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
      ),
    );
  }
}

class _RightNowCard extends ConsumerWidget {
  const _RightNowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase =
        ref.watch(dayPhaseProvider).value ?? DayPhase.fromClock(DateTime.now());
    // After hours, the lead card adds nothing — the greeting already
    // reads "Good evening". Don't consume scroll.
    if (phase == DayPhase.closed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final labels = ref.watch(verticalLabelsProvider);
    final kids = labels.subjectPlural.toLowerCase();
    final spec = _phaseSpec(phase, theme.colorScheme, kids);

    // Arrival: replace the static line with live "M of N in" progress when
    // attendance has loaded a non-empty roster (docs/WORKFLOWS.md).
    var line = spec.line;
    if (phase == DayPhase.arrival) {
      final prog = ref.watch(arrivalProgressProvider).value;
      if (prog != null && prog.total > 0) {
        line = prog.allIn
            ? 'All ${prog.total} checked in — nice work.'
            : '${prog.inBuilding} of ${prog.total} in · '
                  '${prog.stillOut} still to check in';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: spec.container,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push(spec.route));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: spec.accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(spec.icon, color: spec.onAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RIGHT NOW',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: spec.onContainer.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        spec.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: spec.onContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: spec.onContainer.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: spec.onContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Presentation for one [DayPhase]: copy, icon, destination, colors.
/// Colors are drawn from the M3 [ColorScheme] (guaranteed-contrast
/// container/on-container pairs). Arrival owns `primaryContainer` — the
/// day's loudest moment — and the standing Morning-checklist card is
/// suppressed during arrival so the two never stack as twins. Every
/// other phase uses a calmer tone so it never clashes with that
/// always-present primary card.
_PhaseSpec _phaseSpec(DayPhase phase, ColorScheme cs, String kids) {
  switch (phase) {
    case DayPhase.prep:
      return _PhaseSpec(
        title: 'Getting ready',
        line: 'Program opens soon — peek at today’s schedule.',
        route: '/schedule',
        icon: Icons.wb_twilight_outlined,
        container: cs.tertiaryContainer,
        onContainer: cs.onTertiaryContainer,
        accent: cs.tertiary,
        onAccent: cs.onTertiary,
      );
    case DayPhase.arrival:
      return _PhaseSpec(
        title: 'Arrival time',
        line: 'Check $kids in as they arrive — see who’s still out.',
        route: '/checklist?filter=unmarked',
        icon: Icons.login,
        container: cs.primaryContainer,
        onContainer: cs.onPrimaryContainer,
        accent: cs.primary,
        onAccent: cs.onPrimary,
      );
    case DayPhase.program:
      return _PhaseSpec(
        title: 'Program time',
        line: 'Blocks are running — here’s what’s now and next.',
        route: '/schedule',
        icon: Icons.play_circle_outline,
        container: cs.tertiaryContainer,
        onContainer: cs.onTertiaryContainer,
        accent: cs.tertiary,
        onAccent: cs.onTertiary,
      );
    case DayPhase.pickup:
      return _PhaseSpec(
        title: 'Pickup time',
        line: 'Release $kids to authorized pickup as families arrive.',
        route: '/pickup',
        icon: Icons.directions_walk,
        container: cs.secondaryContainer,
        onContainer: cs.onSecondaryContainer,
        accent: cs.secondary,
        onAccent: cs.onSecondary,
      );
    case DayPhase.closed:
      // Never rendered (the card early-returns on closed) — fall back to
      // the calm prep spec so the switch stays exhaustive.
      return _PhaseSpec(
        title: 'Getting ready',
        line: 'Program opens soon — peek at today’s schedule.',
        route: '/schedule',
        icon: Icons.wb_twilight_outlined,
        container: cs.tertiaryContainer,
        onContainer: cs.onTertiaryContainer,
        accent: cs.tertiary,
        onAccent: cs.onTertiary,
      );
  }
}

class _PhaseSpec {
  const _PhaseSpec({
    required this.title,
    required this.line,
    required this.route,
    required this.icon,
    required this.container,
    required this.onContainer,
    required this.accent,
    required this.onAccent,
  });

  final String title;
  final String line;
  final String route;
  final IconData icon;
  final Color container;
  final Color onContainer;
  final Color accent;
  final Color onAccent;
}

/// Optional "Today's words" lead-in to Action Words — appears only when
/// at least one child has picked their words today, so it's invisible for
/// programs that don't use the feature. docs/ACTION_WORDS.md.
class _ActionWordsCard extends ConsumerWidget {
  const _ActionWordsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(actionWordsPickedTodayProvider);
    if (n == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.tertiaryContainer,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push('/action-words'));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: theme.colorScheme.onTertiary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Action Words',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n == 1
                            ? '1 child picked today — reveal their world at '
                                  'closing'
                            : '$n children picked today — reveal their worlds '
                                  'at closing',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer
                              .withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The live curriculum world — "this week, the room is in World of X." Taps
/// through to the This Week hub (cast / worksheets / activities). Renders a
/// setup prompt to the director until the journey is started, and nothing
/// at all for everyone else until then.
class _ThisWeekWorldCard extends ConsumerWidget {
  const _ThisWeekWorldCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final world = ref.watch(currentWorldProvider);

    if (world == null) {
      final isDirector = ref.watch(viewerProvider).isDirector;
      if (!isDirector) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(context.push('/this-week'));
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  const Icon(Icons.rocket_launch_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Start the 10-week journey',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final accent = world.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: accent.withValues(alpha: 0.14),
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push('/this-week'));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Text(world.emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Week ${world.week} · ${world.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '“${world.question}”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One teachable skill a day, with a 2-minute "how". A suggestion rotates
/// daily; tap to browse + pick another. Keeps the daily-skill promise from
/// being hollow without adding a navigation stack.
class _TodaySkillCard extends StatelessWidget {
  const _TodaySkillCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skill = skillForDay(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(_browse(context));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Text(skill.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today’s skill · ${skill.name}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        skill.how,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _browse(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Skills to teach',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final s in kSkills)
                  ListTile(
                    leading: Text(
                      s.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                    title: Text(s.name),
                    subtitle: Text(s.how),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Today's thinking" — a rotating Big Thinking game (play → name → bridge
/// → question). Tap → the deck.
class _TodayThinkingCard extends ConsumerWidget {
  const _TodayThinkingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final games = ref.watch(thinkingGamesProvider).value ?? const [];
    // This week's WORLD game leads; off-curriculum falls back to the rotation.
    final weekGames = ref.watch(thisWeekThinkingProvider);
    final fromWeek = weekGames.isNotEmpty;
    final game = thinkingGameForDay(
      fromWeek ? weekGames : games,
      DateTime.now(),
    );
    if (game == null) return const SizedBox.shrink();
    final label = fromWeek ? 'This week’s thinking' : 'Today’s thinking';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push('/thinking'));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Text(game.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label · ${game.concept}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        game.play,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TodayBody extends ConsumerWidget {
  const TodayBody({
    required this.member,
    required this.groups,
    required this.space,
    required this.viewer,
    super.key,
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
    // The day's current phase drives the time-aware lead card and lets
    // us suppress the standing checklist card during arrival (the lead
    // already leads with check-in there).
    final phase =
        ref.watch(dayPhaseProvider).value ?? DayPhase.fromClock(DateTime.now());

    return ResponsivePage(
      bottomPadding: 24,
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
        // "Ready to run?" — the pre-9:00 setup check. Renders nothing once the
        // gating preconditions are met (or for non-directors). The first thing
        // a brand-new program sees; vanishes the moment it's set up.
        const _ReadyToRunCard(),
        // "A session is live — tap to join" (renders nothing when none).
        const LiveSessionBanner(),
        // The live curriculum world (renders nothing until the
        // 10-week journey is started; shows a setup prompt to the
        // director). The daily anchor: "this week, the room is in X."
        const _ThisWeekWorldCard(),
        // "Today's skill" — one teachable thing a day, with a how
        // (closes the brief's skill-a-day; staff-only).
        if (viewer.isDailyLogger) const _TodaySkillCard(),
        // "Today's thinking" — a play→name→bridge→question game.
        if (viewer.isDailyLogger) const _TodayThinkingCard(),
        // Specialist / substitute identity strip — answers the
        // Coach Sam audit finding ("no UI surface tells Sam what
        // they are"). Renders nothing for director / lead_teacher
        // / teacher / guardian because context already makes the
        // role obvious. Tap → Roles page so Sam can see what their
        // role can do.
        const _IdentityStrip(),
        // Time-aware lead: orients Today to the day's phase
        // (arrival → check-in, program → schedule, pickup → roster).
        // Renders nothing after hours. docs/WORKFLOWS.md gap #1.
        if (viewer.isDailyLogger) const _RightNowCard(),
        // Morning Checklist is only useful to staff who can
        // actually mark daily routines — hide for read-only viewers.
        // Suppressed during arrival, where the Right-now card already
        // leads with check-in (so the two don't stack as primary
        // twins).
        if (viewer.isDailyLogger && phase != DayPhase.arrival)
          const _ChecklistCallToAction(),
        if (viewer.isDailyLogger && phase != DayPhase.arrival)
          const SizedBox(height: 16),
        // "You're leading N blocks today" — renders nothing if
        // the signed-in member isn't a lead on any block today.
        // Naturally hides for non-staff and members with no
        // assignments.
        const LeadingTodayCard(),
        const SizedBox(height: 16),
        // "Today's words" — only when Action Words is in use today.
        if (viewer.isDailyLogger) const _ActionWordsCard(),
        // Unread family messages — staff-side proactive surface
        // (Wave 60). Renders only when at least one family has
        // sent a message that nobody on staff has read yet.
        // Each row taps through to that (subject, guardian)
        // thread. Hidden for guardians (their messages flow is
        // through the family lens).
        const _UnreadMessagesCard(),
        // Director's morning pulse — aggregates absent kids,
        // cohorts with substitute coverage today, and
        // expiring-soon certs into a single card. Renders
        // nothing when there's nothing to flag (the "all clear"
        // case doesn't need to consume scroll). Only directors
        // see this; non-directors hit the early-return.
        if (viewer.isDirector) _DirectorPulseCard(groups: groups),
        // Upward loop made visible: the system surfaces one
        // question here when the data demands it; silent when
        // it doesn't. UX_DECISIONS §6 / framework upward loop.
        const TopInsightCard(),
        const SizedBox(height: 16),
        // Capability-aware one-tap launchpad. Hides itself when the
        // viewer has nothing to launch.
        const QuickActions(),
        const SizedBox(height: 24),
        // Wave 114: at desktop widths the group cards flow as a
        // 2-column wrap. At phone / tablet they stack vertically
        // (the natural shape for a scroll-with-omnibox layout).
        // LayoutBuilder reads the current viewport once; cards
        // self-size in their columns.
        LayoutBuilder(
          builder: (ctx, c) {
            final isWide = c.maxWidth >= 1100;
            if (!isWide) {
              return Column(
                children: [
                  for (final g in groups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RepaintBoundary(
                        child: _GroupTodayCard(group: g),
                      ),
                    ),
                ],
              );
            }
            // Desktop: 2-column wrap. Each card claims ~half the
            // available width minus the column gap.
            const gap = 12.0;
            final cardWidth = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final g in groups)
                  SizedBox(
                    width: cardWidth,
                    child: RepaintBoundary(
                      child: _GroupTodayCard(group: g),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _subtitleLine({
    required Member? member,
    required int totalFlags,
    required int roomsWithFlags,
    required VerticalLabels labels,
  }) {
    if (totalFlags > 0) {
      final subj = totalFlags == 1
          ? labels.subject.toLowerCase()
          : labels.subjectPlural.toLowerCase();
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
                data: (state) => _DayStateRow(state: state, groupId: group.id),
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
        ref.watch(scheduleDayProvider(todayIso())).value ??
        const <ScheduleBlock>[];
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

    // Incidents still awaiting a family call — the compliance gap a
    // director most wants caught the next morning (e.g. one logged
    // yesterday afternoon that nobody marked notified). Gated on the
    // program feature.
    final viewer = ref.watch(viewerProvider);
    final needFollowUp = viewer.featureIncidentReports
        ? (ref.watch(incidentsInSpaceProvider).value ?? const <Incident>[])
              .where((i) => !i.parentNotified)
              .length
        : 0;

    final nothing =
        absent == 0 &&
        substituteGroups == 0 &&
        expiring == 0 &&
        needFollowUp == 0;

    return SectionCard(
      visible: !nothing,
      borderRadius: 16,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      icon: Icons.dashboard_outlined,
      title: "Today's pulse",
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Each row taps through to where the director would
            // actually act on the flag (Wave 64 UX rerank). Before
            // these were no-ops (maybePop on root) which was the
            // single biggest UX miss on Today.
            if (absent > 0)
              _PulseRow(
                icon: Icons.event_busy_outlined,
                tint: scheme.error,
                label:
                    '$absent ${absent == 1 ? "kid" : "kids"} '
                    'absent today',
                onTap: () => context.push('/checklist'),
              ),
            if (substituteGroups > 0)
              _PulseRow(
                icon: Icons.person_add_alt_1,
                tint: scheme.tertiary,
                label: substituteGroups == 1
                    ? '1 cohort with a substitute covering today'
                    : '$substituteGroups cohorts with a substitute '
                          'covering today',
                onTap: () => context.push('/schedule'),
              ),
            if (expiring > 0)
              _PulseRow(
                icon: Icons.verified_outlined,
                tint: scheme.tertiary,
                label:
                    '$expiring ${expiring == 1 ? "cert" : "certs"} '
                    'expiring in the next 30 days',
                onTap: () => context.push('/settings/team'),
              ),
            if (needFollowUp > 0)
              _PulseRow(
                icon: Icons.report_gmailerrorred_outlined,
                tint: scheme.error,
                label: needFollowUp == 1
                    ? '1 incident needs a family call'
                    : '$needFollowUp incidents need a family call',
                onTap: () => context.push('/incidents?filter=followup'),
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

/// Staff-side Today card — surfaces every (subject, guardian) thread
/// that has at least one unread family-sent message. Hidden when the
/// inbox is empty so the "all caught up" case doesn't add chrome.
/// Tapping a row opens that specific thread.
class _UnreadMessagesCard extends ConsumerWidget {
  const _UnreadMessagesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(unreadThreadsForStaffProvider);
    final theme = Theme.of(context);
    final visible = threads.length > 4 ? threads.sublist(0, 4) : threads;
    final totalUnread = threads.fold<int>(0, (sum, t) => sum + t.unreadCount);
    return SectionCard(
      visible: threads.isNotEmpty,
      icon: Icons.mark_chat_unread_outlined,
      tone: SectionCardTone.featured,
      title: totalUnread == 1
          ? '1 unread message'
          : '$totalUnread unread messages',
      trailing: threads.length > visible.length
          ? Text(
              '+${threads.length - visible.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withValues(
                  alpha: 0.7,
                ),
              ),
            )
          : null,
      child: Column(
        children: [
          for (final t in visible) _UnreadThreadRow(thread: t),
        ],
      ),
    );
  }
}

class _UnreadThreadRow extends ConsumerWidget {
  const _UnreadThreadRow({required this.thread});

  final UnreadThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subjectAsync = ref.watch(subjectByIdProvider(thread.subjectId));
    final subject = subjectAsync.value;
    final subjectName = subject == null
        ? 'A child'
        : '${subject.firstName} ${subject.lastName}'.trim();
    return InkWell(
      onTap: () => context.push(
        '/messages/${thread.subjectId}/${thread.guardianId}',
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          children: [
            Icon(
              Icons.forum_outlined,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$subjectName · ${thread.unreadCount} new',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thread.latestBody,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
