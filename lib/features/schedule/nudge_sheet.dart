import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/action_words/block_run.dart';
import 'package:differentworld/features/schedule/nudge.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _kindEmoji(String kind) => switch (kind) {
  'break' => '🍎',
  'field_trip' => '🚌',
  'closed' => '👋',
  _ => '🎯',
};

/// One remaining block with its real clock window — kept so the apply can honour
/// fixed blocks' original times.
typedef _Remaining = ({ScheduleBlock block, DateTime start, DateTime end});

List<_Remaining> _remainingBlocks(List<ScheduleBlock> blocks, DateTime now) {
  final out = <_Remaining>[];
  for (final b in blocks) {
    if (b.status == 'skipped' || b.status == 'cancelled') continue;
    final start = DateTime.tryParse(b.startAt)?.toLocal();
    final end = DateTime.tryParse(b.endAt)?.toLocal();
    if (start == null || end == null || end.isBefore(now)) continue;
    out.add((block: b, start: start, end: end));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// Build the recomposer's slots. A currently-running first block contributes its
/// REMAINING time (not the full scheduled duration); the day-ender (last block)
/// is marked fixed so a nudge never shrinks or moves pickup.
List<NudgeSlot> _slots(List<_Remaining> remaining, DateTime now) => [
  for (var i = 0; i < remaining.length; i++)
    () {
      final r = remaining[i];
      final title = (r.block.title ?? '').trim();
      final running = r.start.isBefore(now);
      final mins = (running ? r.end.difference(now) : r.end.difference(r.start))
          .inMinutes
          .clamp(1, 600);
      final isFixed =
          r.block.kind == 'closed' ||
          i == remaining.length - 1 || // the day-ender always holds its time
          title.toLowerCase().contains('pickup');
      return (
        id: r.block.id,
        title: title.isEmpty ? 'Block' : title,
        emoji: _kindEmoji(r.block.kind),
        minutes: mins,
        energy: blockEnergy(r.block.kind, r.block.title ?? ''),
        fixed: isFixed,
      );
    }(),
];

/// The whole "nudge the day" flow — build the plan from today's remaining
/// blocks, show the confirm-diff, and (on apply) re-pack + write the new times
/// in ONE transaction. Optimistic + offline-first (Drift → PowerSync).
Future<void> nudgeTheDay(
  BuildContext context,
  WidgetRef ref, {
  required NudgeIntent intent,
  required List<ScheduleBlock> blocks,
}) async {
  if (!context.mounted) return;
  final now = DateTime.now();
  final remaining = _remainingBlocks(blocks, now);
  if (remaining.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing left to nudge today.')),
    );
    return;
  }
  // Anchor the re-pack at NOW when the first block is already running (its start
  // is in the past) — so the budget is the real remaining wall-clock and no
  // block is ever written with an end in the past.
  final anchor = remaining.first.start.isBefore(now)
      ? now
      : remaining.first.start;
  final lastEnd = remaining
      .map((r) => r.end)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  final availableMin = lastEnd.difference(anchor).inMinutes;
  if (availableMin <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Today's blocks are already done.")),
    );
    return;
  }
  final plan = recomposeNudge(
    _slots(remaining, now),
    availableMin,
    intent,
    endLabel: timeOfDay(lastEnd),
  );

  final applied = await showNudgeDiffSheet(context, plan: plan, intent: intent);
  if (applied != true || !context.mounted) return;

  // Fixed blocks (pickup / the day-ender) keep their ORIGINAL clock time; the
  // flexible blocks re-pack sequentially from the anchor. All writes land in one
  // transaction so a watching device never sees a half-recomposed schedule.
  final original = {for (final r in remaining) r.block.id: r};
  final db = await ref.read(appDatabaseProvider.future);
  final actions = ref.read(scheduleActionsProvider);
  await db.transaction(() async {
    var cursor = anchor;
    for (final s in plan.ordered) {
      final orig = original[s.id];
      final DateTime start;
      final DateTime end;
      if (s.fixed && orig != null) {
        start = orig.start;
        end = orig.end;
      } else {
        start = cursor;
        end = cursor.add(Duration(minutes: s.minutes));
        cursor = end;
      }
      await actions.update_(id: s.id, startAt: start, endAt: end);
    }
  });
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Day updated.')),
  );
}

String _intentTitle(NudgeIntent i) => switch (i) {
  NudgeIntent.behind => 'Running behind?',
  NudgeIntent.wired => 'Kids are wired?',
  NudgeIntent.ahead => 'Ahead of schedule?',
};

/// The confirm-diff sheet — the before→after change, nothing applied until the
/// host taps Apply. The buttons are single-fire (a `decided` guard) so a
/// double-tap can't pop twice and pop the run-day underneath. Returns true iff
/// applied.
Future<bool?> showNudgeDiffSheet(
  BuildContext context, {
  required NudgePlan plan,
  required NudgeIntent intent,
}) {
  return showGlassSheet<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      final changed = plan.changes.where((c) => c.changed).toList();
      var decided = false;
      void decide({required bool apply}) {
        if (decided) return;
        decided = true;
        Navigator.of(ctx).pop(apply);
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _intentTitle(intent),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    'nothing changed yet',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (!plan.isNoop) ...[
                const SizedBox(height: 14),
                for (final c in changed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(
                          c.slot.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.slot.title,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        if (c.moved && !c.shrank && !c.grew)
                          Text(
                            'moved up',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else ...[
                          Text(
                            '${c.oldMinutes}m',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            '  →  ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${c.newMinutes}m',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 18),
              if (plan.isNoop)
                FilledButton(
                  onPressed: () => decide(apply: false),
                  child: const Text('Got it'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => decide(apply: true),
                        child: const Text('Apply'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => decide(apply: false),
                      child: const Text('Not now'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// The "nudge the day" bar — three plain-language chips on the run-day. Tapping
/// one runs [nudgeTheDay]; all three disable while a nudge is in flight so a
/// second tap can't recompose from stale (pre-apply) times.
class NudgeBar extends ConsumerStatefulWidget {
  const NudgeBar({required this.blocks, super.key});

  final List<ScheduleBlock> blocks;

  @override
  ConsumerState<NudgeBar> createState() => _NudgeBarState();
}

class _NudgeBarState extends ConsumerState<NudgeBar> {
  bool _busy = false;

  Future<void> _go(NudgeIntent intent) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await nudgeTheDay(context, ref, intent: intent, blocks: widget.blocks);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nudge the day',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Text('🏃'),
                label: const Text('Running behind'),
                onPressed: _busy
                    ? null
                    : () => unawaited(_go(NudgeIntent.behind)),
              ),
              ActionChip(
                avatar: const Text('⚡'),
                label: const Text('Kids are wired'),
                onPressed: _busy
                    ? null
                    : () => unawaited(_go(NudgeIntent.wired)),
              ),
              ActionChip(
                avatar: const Text('🌤'),
                label: const Text('Ahead of schedule'),
                onPressed: _busy
                    ? null
                    : () => unawaited(_go(NudgeIntent.ahead)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
