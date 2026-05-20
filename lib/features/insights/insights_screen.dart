import 'dart:async';

import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/insights/insights_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/insights` — the full list of questions the system is surfacing
/// right now. Grouped by severity (Urgent / Suggestions / FYI) so the
/// most time-sensitive stuff is at the top.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final insightCount = insightsAsync.value?.length ?? 0;
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      floatingActionButton: insightCount >= 2
          ? FloatingActionButton.extended(
              onPressed: () {
                unawaited(HapticFeedback.selectionClick());
                unawaited(context.push('/review'));
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Walk me through'),
            )
          : null,
      body: insightsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not compute insights',
          onRetry: () => ref.invalidate(insightsProvider),
        ),
        data: (insights) {
          if (insights.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All clear',
              message:
                  "Nothing's calling for attention right now. The system "
                  'watches your data and surfaces questions here when '
                  'patterns show up.',
            );
          }
          final urgent = insights
              .where((i) => i.severity == InsightSeverity.urgent)
              .toList();
          final suggestion = insights
              .where((i) => i.severity == InsightSeverity.suggestion)
              .toList();
          final info =
              insights.where((i) => i.severity == InsightSeverity.info).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: 'Insights',
                  subtitle:
                      'Questions the system is surfacing from your data',
                ),
              ),
              if (urgent.isNotEmpty)
                _SeverityGroup(label: 'URGENT', insights: urgent),
              if (suggestion.isNotEmpty)
                _SeverityGroup(
                  label: 'SUGGESTIONS',
                  insights: suggestion,
                ),
              if (info.isNotEmpty)
                _SeverityGroup(label: 'FYI', insights: info),
            ],
          );
        },
      ),
    );
  }
}

class _SeverityGroup extends StatelessWidget {
  const _SeverityGroup({required this.label, required this.insights});

  final String label;
  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        for (final i in insights)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: InsightCard(insight: i),
          ),
      ],
    );
  }
}

/// Reusable card — one insight with its prompt + action buttons. Used
/// by the full list screen AND by Today's "top insight" slot, so the
/// visual language stays consistent across surfaces.
class InsightCard extends ConsumerWidget {
  const InsightCard({required this.insight, super.key});

  final Insight insight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (bg, fg) = _colorsFor(insight.severity, theme);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(insight.icon, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insight.prompt,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ),
              _SnoozeButton(insightId: insight.id, foreground: fg),
            ],
          ),
          if (insight.actions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: -8,
              children: [
                // Default action: prominent filled button.
                FilledButton(
                  onPressed: () =>
                      context.push(insight.actions.first.route),
                  child: Text(insight.actions.first.label),
                ),
                // Secondary actions render as text buttons.
                for (final a in insight.actions.skip(1))
                  TextButton(
                    onPressed: () => context.push(a.route),
                    child: Text(a.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color) _colorsFor(InsightSeverity s, ThemeData theme) {
    final scheme = theme.colorScheme;
    return switch (s) {
      InsightSeverity.urgent => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      InsightSeverity.suggestion => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      InsightSeverity.info => (
          scheme.surfaceContainerHighest,
          scheme.onSurface,
        ),
    };
  }
}

/// Overflow menu in the corner of every InsightCard. The user picks
/// a snooze duration; the card vanishes immediately (the underlying
/// `dismissed_insights` row arrives in the stream and filters the
/// insight out next frame).
class _SnoozeButton extends ConsumerWidget {
  const _SnoozeButton({required this.insightId, required this.foreground});

  final String insightId;
  final Color foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<InsightSnoozeOption>(
      tooltip: 'Snooze',
      icon: Icon(Icons.more_horiz, color: foreground),
      onSelected: (option) async {
        final actions = ref.read(insightActionsProvider);
        await runReported(
          library: 'insights',
          action: () => actions.snooze(
            insightId: insightId,
            option: option,
          ),
        );
      },
      itemBuilder: (_) => [
        for (final opt in InsightSnoozeOption.values)
          PopupMenuItem(value: opt, child: Text(opt.label)),
      ],
    );
  }
}

/// Today's slot — renders the single highest-severity insight as a
/// card with a peek-link to the full list. Empty when there's
/// nothing to surface (the framework's whole point is silence when
/// the system has nothing to ask).
class TopInsightCard extends ConsumerWidget {
  const TopInsightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsProvider);
    final insights = insightsAsync.value ?? const <Insight>[];
    if (insights.isEmpty) return const SizedBox.shrink();
    final top = insights.first;
    final rest = insights.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsightCard(insight: top),
        if (rest > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/insights'),
              child: Text(
                rest == 1
                    ? '1 more — see all'
                    : '$rest more — see all',
              ),
            ),
          ),
      ],
    );
  }
}
