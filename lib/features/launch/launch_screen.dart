import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/launch/launch_readiness.dart';
import 'package:differentworld/features/readiness/readiness_providers.dart';
import 'package:differentworld/features/readiness/widgets/readiness_card.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/ready` — where the program stands. Three questions, one page.
///
/// Setup state is scattered across the journey, the roster and the schedule,
/// so this composes the real preconditions into one checklist. Each unmet
/// item carries its fix one tap away.
///
/// **It answers three different questions, and they arrive at different
/// times in a director's life:** what do I do when I first sign up, what is
/// happening right now, and what needs me. Today already surfaces the last
/// two — but as SELF-RETIRING cards, which is correct for news on a home
/// screen and useless as a reference. A card that vanishes when satisfied
/// cannot answer "are we actually fine?", because silence and
/// not-running look identical.
///
/// So this is the page you come to ON PURPOSE, and the rule inverts: when
/// nothing needs attention it SAYS SO rather than disappearing.
class LaunchScreen extends ConsumerWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = ref.watch(launchReadinessProvider);
    final ready = allReady(items);
    final count = readyCount(items);
    return EdgeScaffold(
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Where you stand',
            subtitle: 'What is set up, what is running, and what needs you',
          ),
          // The verdict.
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: ready
                  ? AppColors.growthOf(theme).withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  ready ? Icons.check_circle : Icons.pending_outlined,
                  color: ready
                      ? AppColors.growthOf(theme)
                      : theme.colorScheme.onSurfaceVariant,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ready
                            ? "You're ready to run tomorrow."
                            : '${count.done} of ${count.total} ready',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ready
                            ? 'Print the basket tonight and open Today at 9:00.'
                            : 'A couple of things left — each is one tap.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final item in items) _ReadyRow(item: item),
          const SizedBox(height: 28),
          const _RunningNow(),
          const SizedBox(height: 28),
          const _NeedsYou(),
        ],
      ),
    );
  }
}

/// What is happening right now — the band that turns a setup checklist into
/// a standing view. Renders nothing outside program hours, where "nothing is
/// running" is the expected state rather than information.
class _RunningNow extends ConsumerWidget {
  const _RunningNow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final live = ref.watch(liveBlockProvider);
    if (live == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
        ),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Running now', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          // Every row on this page goes SOMEWHERE. A standing view whose
          // items you can only read is a report; the point is that seeing
          // a thing and fixing it are one gesture. This band shipped
          // unreadable-and-untappable for exactly one build.
          InkWell(
            // The ROOM, not the block-run sheet: that route needs a full
            // ScheduleBlock row via `extra`, and LiveBlock carries only the
            // id — passing a query param would land on the schedule screen
            // instead, which is the dead-end-that-navigates this page is
            // supposed to be free of. The room is the better destination
            // anyway: it holds attendance, pick-me and observations for the
            // block that is running.
            onTap: () => unawaited(context.push('/groups/${live.groupId}')),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(live.title, style: theme.textTheme.bodyLarge),
                        Text(
                          'until ${timeOfDay(live.endAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What needs you — the same items as the Today card, but this one SPEAKS
/// WHEN EMPTY.
///
/// On Today, vanishing is right: a permanent list of chores is a sign on a
/// wall. Here, vanishing would be the bug — you came to this page to ask,
/// and getting no answer is indistinguishable from the check not running.
class _NeedsYou extends ConsumerWidget {
  const _NeedsYou();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = ref.watch(readinessProvider);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: items.isEmpty
                ? theme.colorScheme.outlineVariant
                : theme.colorScheme.error,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('Needs you', style: theme.textTheme.titleMedium),
              ),
              if (items.isNotEmpty)
                Text(
                  '${items.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text(
              'Nothing right now — every child has a guardian, an allergy '
              'answer and a photo decision on file.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            // Reuses the Today card wholesale rather than reimplementing its
            // rows: one place decides what an unmet item says and where it
            // lands, so the two surfaces cannot drift apart.
            const ReadinessCard(),
        ],
      ),
    );
  }
}

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({required this.item});
  final ReadyItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, tone) = switch (item.status) {
      ReadyStatus.done => (Icons.check_circle, AppColors.growthOf(theme)),
      ReadyStatus.todo => (
        Icons.radio_button_unchecked,
        theme.colorScheme.primary,
      ),
      ReadyStatus.info => (
        Icons.info_outline,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: tone, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.why.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.why,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (item.actionLabel != null && item.actionRoute != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () => context.push(item.actionRoute!),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(item.actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
