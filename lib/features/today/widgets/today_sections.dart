import 'dart:async';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/journey_day_sheet.dart';
import 'package:differentworld/features/action_words/reveal_overlay.dart';
import 'package:differentworld/features/action_words/skills.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/certifications/certifications_providers.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/features/insights/insights_screen.dart';
import 'package:differentworld/features/launch/launch_readiness.dart';
import 'package:differentworld/features/live_session/live_session_banner.dart';
import 'package:differentworld/features/messages/messages_providers.dart';
import 'package:differentworld/features/onboarding/widgets/starter_spine.dart';
import 'package:differentworld/features/readiness/widgets/readiness_card.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/widgets/leading_today_card.dart';
import 'package:differentworld/features/schedule/widgets/now_next_strip.dart';
import 'package:differentworld/features/settings/widgets/starting_simple_note.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/features/today/widgets/context_pill.dart';
import 'package:differentworld/features/today/widgets/quick_actions.dart';
import 'package:differentworld/shared/widgets/collapsible_section.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:differentworld/shared/widgets/section_eyebrow.dart';
import 'package:differentworld/shared/widgets/skeleton.dart';
import 'package:differentworld/shared/widgets/status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
                        '${count.done} of ${count.total} ready — finish setup.',
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

/// The time-aware lead card — the first useful move on Today. Orients the
/// whole screen to the day's current phase via the wall clock
/// ([dayPhaseProvider]) and points to the surface that matters *right now*:
/// arrival → check-in, **program → run the day on rails** (when a curriculum
/// world is live), pickup → the roster. It only *leads the eye* to surfaces
/// that already exist — no new data layer. Hidden after hours.
/// The contextual lead — Today's one "what matters right now" surface. It
/// renders [contextLeadProvider]: a moment-aware header plus the 1–3 labeled
/// moves that moment actually calls for (a field trip reveals the vehicle +
/// roster; an activity reveals run/observe/attendance). The "only immediate
/// utility per context" law lives in the provider; this is the renderer.
class _RightNowCard extends ConsumerWidget {
  const _RightNowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(contextLeadProvider);
    // Nothing to lead with — a signed-in non-logger, or closed for the day.
    if (lead == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (
      Color container,
      Color onContainer,
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
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        scheme.primary,
        scheme.onPrimary,
      ),
    };

    final moves = <ContextMove>[lead.primary, ...lead.more];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        // Full-bleed (no Card margin) so the tinted block's left lines up with
        // the cohort rows; the glyph hangs in the shared 44dp gutter, landing
        // the header on the one edge.
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: container,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(lead.icon, color: onAccent, size: 20),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 0.78 not 0.7 — keeps the eyebrow ≥4.5:1 against the
                    // container even in the high-contrast outdoor theme.
                    SectionEyebrow(
                      lead.eyebrow,
                      color: onContainer.withValues(alpha: 0.78),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lead.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onContainer,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lead.line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onContainer.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // The moves. First is primary (filled accent); the rest
                    // are quieter outlined chips. Only the moment's utility.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, m) in moves.indexed)
                          _LeadChip(
                            // Keyed by route so a phase boundary changing the
                            // move count (1-chip → 2-chip) re-matches chips by
                            // identity, not list position.
                            key: ValueKey('lead-${m.route}'),
                            move: m,
                            primary: i == 0,
                            accent: accent,
                            onAccent: onAccent,
                            onContainer: onContainer,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              unawaited(context.push(m.route));
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single move inside the contextual lead. The primary move is filled with
/// the lead's accent; secondary moves are quiet outlined chips on the tint.
class _LeadChip extends StatelessWidget {
  const _LeadChip({
    required this.move,
    required this.primary,
    required this.accent,
    required this.onAccent,
    required this.onContainer,
    required this.onTap,
    super.key,
  });

  final ContextMove move;
  final bool primary;
  final Color accent;
  final Color onAccent;
  final Color onContainer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? onAccent : onContainer;
    return Material(
      color: primary ? accent : onContainer.withValues(alpha: 0.10),
      shape: StadiumBorder(
        side: primary
            ? BorderSide.none
            : BorderSide(color: onContainer.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // ≥48dp tap target (CLAUDE.md a11y floor). The chips ARE the lead's
        // primary interaction — a miss-tap at arrival / headcount is a real
        // failure — so the hit area meets the floor even though the visual
        // content is shorter (Row centres within the min-height box).
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(move.icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  move.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback orientation for a drop-in — a specialist or substitute who isn't
/// assigned to any block today. The leading-today card is blank for them, so
/// they'd otherwise land on a generic Today with no pointer to the room they're
/// covering. Sends them to the runbook. Renders nothing once they HAVE blocks
/// (leading-today takes over) or for non-drop-in roles.
class _CoveringTodayCard extends ConsumerWidget {
  const _CoveringTodayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (!viewer.isSpecialist && !viewer.isSubstitute) {
      return const SizedBox.shrink();
    }
    final memberId = viewer.memberId;
    if (memberId == null) return const SizedBox.shrink();
    final blocks = ref
        .watch(
          scheduleDayForLeadProvider((memberId: memberId, date: todayIso())),
        )
        .value;
    // Until loaded → nothing (no flicker). Assigned → the leading-today card
    // already shows the blocks, so defer to it.
    if (blocks == null || blocks.isNotEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final covering = viewer.isSubstitute ? 'covering' : 'here';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: scheme.secondaryContainer,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push('/runbook'));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "You're $covering today",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No block assigned to you yet — open the runbook to '
                        'see how the day runs.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line announcement shown when the wall clock crosses into a new phase.
String _phaseAnnouncement(DayPhase phase) => switch (phase) {
  DayPhase.prep => 'Getting ready for the day',
  DayPhase.arrival => 'Arrival time — check kids in',
  DayPhase.program => 'Program time — run the day',
  DayPhase.pickup => 'Pickup time',
  DayPhase.closed => 'The program day is over',
};

/// Persistent safety banner: once the day is running, surfaces children who
/// still have no attendance decision (the arrival lead has moved on). Error-
/// toned and tappable straight into the unmarked filter so the gap can't
/// silently ride through the day.
class _UnmarkedCheckInBanner extends StatelessWidget {
  const _UnmarkedCheckInBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.push('/checklist?filter=unmarked'));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Icon(Icons.report_outlined, color: scheme.onErrorContainer),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    count == 1
                        ? '1 child still not checked in — tap to mark '
                              'attendance'
                        : '$count children still not checked in — tap to mark '
                              'attendance',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Optional "Today's words" lead-in to Action Words — appears only when
/// at least one child has picked their words today, so it's invisible for
/// programs that don't use the feature. docs/ACTION_WORDS.md.
class _ActionWordsCard extends ConsumerWidget {
  const _ActionWordsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the warm reveal line-up (not just the count) so a tap from here
    // can fire the ceremony directly — and so the data is ready when it does.
    final n = ref.watch(todaysRevealItemsProvider).length;
    if (n == 0) return const SizedBox.shrink();
    final phase =
        ref.watch(dayPhaseProvider).value ?? DayPhase.fromClock(DateTime.now());
    // From pickup onward, "at closing" IS now — the card becomes the reveal
    // button so the day's culminating ritual is one tap, not a buried icon
    // on a screen you'd have to find first.
    final closing = phase == DayPhase.pickup || phase == DayPhase.closed;
    final theme = Theme.of(context);
    final title = closing ? 'Closing time' : 'Action Words';
    final line = closing
        ? (n == 1 ? 'Reveal 1 world now' : 'Reveal $n worlds now')
        : (n == 1
              ? '1 child picked today — reveal their world at closing'
              : '$n children picked today — reveal their worlds at closing');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.tertiaryContainer,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            if (closing) {
              unawaited(revealAllPicksToday(context, ref));
            } else {
              unawaited(context.push('/action-words'));
            }
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
                    closing ? Icons.auto_awesome_motion : Icons.auto_awesome,
                    color: theme.colorScheme.onTertiary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line,
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

/// "Today's focus" — the DAY-level deepening below the week-level world card.
/// Where `_ThisWeekWorldCard` says "this week the room is in World X", this
/// says "today (Day N) we do *this*, and *this* goes on the wall". The single
/// surface that answers "how do I run today" at the day grain — staff read it
/// before the room opens. Renders nothing until the journey is active (the
/// week card above already carries the director's setup prompt, so this never
/// duplicates it). Staff-only.
class _TodaysFocusCard extends ConsumerWidget {
  const _TodaysFocusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref.watch(currentProgramDayProvider);
    final journeyDay = ref.watch(todaysJourneyDayProvider);
    final block = ref.watch(currentBlockProvider);
    final wallQuestion = ref.watch(todaysWallQuestionProvider);
    if (day == null || journeyDay == null || block == null) {
      return const SizedBox.shrink();
    }

    final accent = block.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: accent.withValues(alpha: 0.10),
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(
              showJourneyDaySheet(
                context,
                day: day,
                journeyDay: journeyDay,
                block: block,
                wallQuestion: wallQuestion,
                isToday: true,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(block.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today · Day $day of 50',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            journeyDay.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                if (wallQuestion != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.format_quote_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wallQuestion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
    return showGlassSheet<void>(
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

/// The curriculum quartet (world anchor + day focus + skill + thinking)
/// folded into one collapsed-by-default disclosure. Before the journey
/// starts it's just the world card (the director's setup prompt / nothing
/// for others); once a world is live it collapses the whole cluster behind a
/// single "Today's plan" row with a glanceable "world · day" summary, so
/// Today leads with the time-aware action instead of a wall of cards.
class _TodaysPlanSection extends ConsumerWidget {
  const _TodaysPlanSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(currentWorldProvider);
    // No journey yet → keep the world card's setup prompt visible (director)
    // or nothing (others). Nothing to collapse.
    if (world == null) return const _ThisWeekWorldCard();
    final isLogger = ref.watch(viewerProvider).isDailyLogger;
    final day = ref.watch(currentProgramDayProvider);
    final summary = day != null ? '${world.name} · Day $day' : world.name;
    // Collapsed by default: lead with the action, tuck the plan one tap away.
    // The body stays built (CollapsibleSection keeps it warm) so the cards'
    // provider watches don't cold-flash on expand.
    return CollapsibleSection(
      title: "Today's plan",
      icon: Icons.auto_stories_outlined,
      collapsedSummary: summary,
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ThisWeekWorldCard(),
          if (isLogger) const _TodaysFocusCard(),
          if (isLogger) const _TodaySkillCard(),
          if (isLogger) const _TodayThinkingCard(),
        ],
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
    var totalUnmarked = 0;
    for (final g in groups) {
      final state = ref.watch(groupDayStateProvider(g)).value;
      if (state == null) continue;
      if (state.hasFlag) {
        totalFlags += state.flagCount;
        roomsWithFlags += 1;
      }
      totalUnmarked += state.unmarked;
    }
    // The day's current phase drives the time-aware lead card and lets
    // us suppress the standing checklist card during arrival (the lead
    // already leads with check-in there).
    final phase =
        ref.watch(dayPhaseProvider).value ?? DayPhase.fromClock(DateTime.now());
    // A phase boundary is a real handoff — say so once when the clock crosses
    // it (not on every Today open: only when the phase actually changes while
    // this screen is alive). Otherwise the lead card silently morphs and the
    // teacher only notices if they happen to be looking.
    //
    // Intentionally in build(): on a ConsumerWidget, Riverpod de-dupes the
    // listener across rebuilds and tears it down on unmount, and the
    // `from == null` guard suppresses the first-build fire. Don't "fix" this
    // by moving it to a ConsumerStatefulWidget initState — it's correct here.
    ref.listen<AsyncValue<DayPhase>>(dayPhaseProvider, (prev, next) {
      final from = prev?.value;
      final to = next.value;
      if (from == null || to == null || from == to) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(_phaseAnnouncement(to)),
        ),
      );
    });

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
        // Above everything, and only for someone who just joined: a short
        // menu has to explain itself before it is read as a broken install.
        // Self-retiring — both of its buttons end it for good.
        const StartingSimpleNote(),
        // What today needs — self-retiring like the spine below it, and
        // above it because these are the things only fixable while the
        // families are still in the room (docs/READINESS.md).
        const ReadinessCard(),
        // First-run starter spine — self-retiring; renders nothing once
        // day one is done (lib/features/onboarding/widgets/starter_spine.dart).
        const StarterSpine(),
        // Safety net: once the day is running (program/pickup), anyone still
        // unmarked is a real accountability gap — a kid with no attendance
        // decision. The arrival lead has already moved on, so this persists
        // the unfinished check-in above everything until it's resolved.
        if ((phase == DayPhase.program || phase == DayPhase.pickup) &&
            viewer.isDailyLogger &&
            totalUnmarked > 0)
          _UnmarkedCheckInBanner(count: totalUnmarked),
        // "Ready to run?" — the pre-9:00 setup check. Renders nothing once the
        // gating preconditions are met (or for non-directors). The first thing
        // a brand-new program sees; vanishes the moment it's set up.
        const _ReadyToRunCard(),
        // "A session is live — tap to join" (renders nothing when none).
        const LiveSessionBanner(),
        // Time-aware lead — the FIRST thing on Today is the move that
        // matters right now: arrival → check-in, program → run the day on
        // rails, pickup → roster. It leads the screen so the default view
        // IS the next useful action, not a wall of cards to hunt through
        // (the "less hunting" principle). Renders nothing after hours.
        // The correct-me context pill — shows what room/block the lead is
        // reading from, tappable to pin a different room. Self-hides for
        // single-room staff and guardians.
        const ContextPill(),
        if (viewer.isDailyLogger) const _RightNowCard(),
        // ── THE ROOMS ── Today's primary data surface, promoted to sit
        // directly under the lead (briefing reorg). They used to be dead
        // last, under a dozen meta cards — a teacher opening the app to
        // check the rooms had to scroll past everything. Now they're second.
        // At desktop widths they flow as a 2-column wrap; on phone/tablet
        // they stack. LayoutBuilder reads the viewport once; cards self-size.
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
        const SizedBox(height: 16),
        // "You're leading N blocks today" — the role anchor. Renders nothing
        // if the member isn't a lead on any block today.
        const LeadingTodayCard(),
        // Drop-in (specialist / substitute) fallback when they have no
        // assigned block — points at the runbook.
        const _CoveringTodayCard(),
        // Unread family messages — staff-side proactive surface. Renders only
        // when a family has sent something nobody on staff has read.
        const _UnreadMessagesCard(),
        // Director's morning pulse — absent kids + sub coverage + expiring
        // certs. Self-hides when all-clear; director-only.
        if (viewer.isDirector) _DirectorPulseCard(groups: groups),
        const SizedBox(height: 16),
        // State-driven launchpad — pending captures / tasks / a vehicle out.
        // Self-hides when nothing's pending. (The static nav tiles moved to
        // the omnibox + drawer in the briefing reorg.)
        const QuickActions(),
        // The day's curriculum plan — only while it's actionable (prep +
        // program). During arrival / pickup it's noise; the moment's lead and
        // the rooms are the job. Reachable any time via the omnibox.
        if (phase == DayPhase.prep || phase == DayPhase.program) ...[
          const SizedBox(height: 8),
          const _TodaysPlanSection(),
        ],
        // "Today's words" — only when Action Words is in use today.
        if (viewer.isDailyLogger) const _ActionWordsCard(),
        // Specialist / substitute identity strip — self-hides for every
        // other role (the Coach Sam orientation answer).
        const _IdentityStrip(),
        // The system's one surfaced question, when the data demands it.
        const TopInsightCard(),
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

    final state = stateAsync.value;
    final dotKind = state == null ? StatusDotKind.neutral : _dotKindFor(state);
    // Marked-of-total, pinned to the row's right edge — the glanceable
    // headline (the pills below break it down). Hidden until the roster
    // loads or when the cohort has no children enrolled.
    final countLabel = (state == null || state.totalSubjects == 0)
        ? null
        : '${state.markedCount} of ${state.totalSubjects}';

    // One-edge row: the scan-dot + room glyph hang in FeatureCard's leading
    // gutter (the same 44dp column every row shares), the name + counts sit on
    // the text edge, and the schedule strip + day-state pills flush below. The
    // standalone "take attendance" icon is gone — the row taps into the cohort
    // and the tappable "unmarked" pill is the fast path into attendance.
    return FeatureCard(
      // `content` overrides the title/subtitle column; `title` stays the
      // semantic name (FeatureCard requires it, falls back to it).
      title: group.name,
      onTap: () => context.push('/groups/${group.id}'),
      leading: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(kind: dotKind),
          const SizedBox(height: 8),
          Icon(
            Icons.meeting_room_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: EntityLink(
                  entity: EntityRef(
                    kind: EntityKind.group,
                    id: group.id,
                    label: group.name,
                  ),
                  padded: false,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (countLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  countLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (group.ageRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                group.ageRange!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 10),
          // "Now / Next" schedule strip — tells the staff scanner what the
          // room is doing this very moment without opening the editor.
          // Renders nothing if the cohort has no blocks today.
          NowNextStrip(groupId: group.id),
          const SizedBox(height: 10),
          stateAsync.when(
            // Shaped skeleton instead of a "Loading…" line — the layout
            // doesn't jump when the data lands.
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
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          // The affordance + the actual wiring: this onTap used to be passed
          // in but never attached — every pulse row was a silent no-op.
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        onTap!.call();
      },
      child: row,
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
