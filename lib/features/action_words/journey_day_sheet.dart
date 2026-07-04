import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/action_words/widgets/mini_accent_label.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/toolkit/toolkit_pdf.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// The shared day-detail read for the 50-day journey — the day's full focus,
/// the wall question, and the block's environment (room / soundtrack / the one
/// moment that matters). Reused by both the Today "today's focus" card and the
/// /this-week fortnight list, so there is ONE day-detail surface, not two.
///
/// [isToday] gates the "Run today" launch into /play-today — it only makes
/// sense for the live day, not when browsing ahead/back.
Future<void> showJourneyDaySheet(
  BuildContext context, {
  required int day,
  required JourneyDay journeyDay,
  required WorldBlock block,
  String? wallQuestion,
  bool isToday = false,
}) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      final accent = block.color;
      // Boundary days carry the room logistics: the FIRST day of a block is
      // when the room gets dressed (arrival); the LAST is when it dissolves
      // into the next world (transition).
      final isFirstDay = block.days.isNotEmpty && day == block.days.first.day;
      final isLastDay = block.days.isNotEmpty && day == block.days.last.day;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab-pill: marks this as a pull-to-dismiss sheet (it renders
              // only on the phone bottom-sheet surface; self-suppresses in the
              // tablet dialog / desktop side-panel). Without it the full-height
              // sheet read as a chrome-less screen — "where's the back button?"
              const Center(child: GlassDragHandle()),
              Row(
                children: [
                  Text(block.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Day $day · ${block.name}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accent,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          journeyDay.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isFirstDay && block.arrival.isNotEmpty) ...[
                const SizedBox(height: 16),
                _BoundaryCallout(
                  icon: Icons.meeting_room_outlined,
                  label: 'Set up the room today',
                  text: block.arrival,
                  accent: accent,
                ),
              ],
              if (isLastDay && block.transition.isNotEmpty) ...[
                const SizedBox(height: 16),
                _BoundaryCallout(
                  icon: Icons.swap_horiz,
                  label: 'Hand off to the next world',
                  text: block.transition,
                  accent: accent,
                ),
              ],
              const SizedBox(height: 18),
              MiniAccentLabel(text: 'Today’s focus', accent: accent),
              const SizedBox(height: 6),
              Text(journeyDay.focus, style: theme.textTheme.bodyMedium),
              if (wallQuestion != null) ...[
                const SizedBox(height: 18),
                MiniAccentLabel(text: 'On the wall', accent: accent),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '“$wallQuestion”',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              MiniAccentLabel(text: 'The room', accent: accent),
              const SizedBox(height: 6),
              _FocusDetailRow(icon: Icons.chair_outlined, text: block.room),
              const SizedBox(height: 8),
              _FocusDetailRow(icon: Icons.graphic_eq, text: block.soundtrack),
              const SizedBox(height: 8),
              _FocusDetailRow(
                icon: Icons.auto_awesome_outlined,
                text: block.keyMoment,
                label: 'If one thing lands',
              ),
              if (block.words.isNotEmpty) ...[
                const SizedBox(height: 18),
                MiniAccentLabel(
                  text: 'The words of this world',
                  accent: accent,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in block.words)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          w,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => unawaited(
                    printDay(
                      block: block,
                      day: day,
                      journeyDay: journeyDay,
                      wallQuestion: wallQuestion,
                    ),
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print this day'),
                ),
              ),
              if (isToday) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final router = GoRouter.of(sheetCtx);
                      Navigator.of(sheetCtx).pop();
                      unawaited(router.push('/play-today'));
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Run today'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// One row in a journey day-list — "Day N · title", with a "Today" badge on
/// the live day. Tapping opens [showJourneyDaySheet]. Used by the /this-week
/// fortnight list.
class JourneyDayRow extends StatelessWidget {
  const JourneyDayRow({
    required this.day,
    required this.journeyDay,
    required this.block,
    this.wallQuestion,
    this.isToday = false,
    super.key,
  });

  final int day;
  final JourneyDay journeyDay;
  final WorldBlock block;
  final String? wallQuestion;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = block.color;
    final isFirstDay = block.days.isNotEmpty && day == block.days.first.day;
    final isLastDay = block.days.isNotEmpty && day == block.days.last.day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isToday
            ? accent.withValues(alpha: 0.12)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
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
                isToday: isToday,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '$day',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    journeyDay.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isToday) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Today',
                      style: theme.textTheme.labelSmall?.copyWith(
                        // Luminance-aware: the lighter world accents (yellow,
                        // gold, cyan) failed AA with hardcoded white.
                        color: AppColors.onAccent(accent),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (isFirstDay)
                  Tooltip(
                    message: 'Set up the room',
                    child: Icon(
                      Icons.meeting_room_outlined,
                      size: 16,
                      color: accent,
                    ),
                  )
                else if (isLastDay)
                  Tooltip(
                    message: 'Flip the room',
                    child: Icon(Icons.swap_horiz, size: 16, color: accent),
                  ),
                if (isFirstDay || isLastDay) const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A prominent room-logistics callout for a block-boundary day — "set up the
/// room" on the first day, "hand off to the next world" on the last. Stronger
/// than the steady-state environment rows because it's a do-it-today action.
class _BoundaryCallout extends StatelessWidget {
  const _BoundaryCallout({
    required this.icon,
    required this.label,
    required this.text,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _FocusDetailRow extends StatelessWidget {
  const _FocusDetailRow({required this.icon, required this.text, this.label});
  final IconData icon;
  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
