import 'dart:async';

import 'package:differentworld/features/action_words/world_blocks.dart';
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
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 18),
              _FocusLabel(text: 'Today’s focus', accent: accent),
              const SizedBox(height: 6),
              Text(journeyDay.focus, style: theme.textTheme.bodyMedium),
              if (wallQuestion != null) ...[
                const SizedBox(height: 18),
                _FocusLabel(text: 'On the wall', accent: accent),
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
              _FocusLabel(text: 'The room', accent: accent),
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
                _FocusLabel(text: 'The words of this world', accent: accent),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in block.words)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
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
              if (isToday) ...[
                const SizedBox(height: 22),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Today',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusLabel extends StatelessWidget {
  const _FocusLabel({required this.text, required this.accent});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
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
