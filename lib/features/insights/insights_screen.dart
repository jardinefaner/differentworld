import 'dart:async';

import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/insights/insights_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the three severity buckets re-lay as
    // bento tiles over the SAME providers; off keeps the existing layout.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      actions: [
        if (insightCount >= 2)
          PrimaryActionButton(
            tooltip: 'Walk me through',
            icon: Icons.play_circle_outline,
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(context.push('/review'));
            },
          ),
        const SyncStatusIndicator(),
      ],
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
          final info = insights
              .where((i) => i.severity == InsightSeverity.info)
              .toList();

          if (bento) {
            return _InsightsBento(
              urgent: urgent,
              suggestion: suggestion,
              info: info,
            );
          }

          // Wave 114: at desktop widths the three severity buckets
          // sit side-by-side as a 3-column dashboard (Urgent left,
          // FYI right). On phone they stack vertically as before.
          return LayoutBuilder(
            builder: (ctx, c) {
              final isWide = c.maxWidth >= 1100;
              const header = Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: 'Insights',
                  subtitle: 'Questions the system is surfacing from your data',
                ),
              );
              if (!isWide) {
                return ResponsivePage(
                  bottomPadding: 32,
                  children: [
                    header,
                    if (urgent.isNotEmpty)
                      _SeverityGroup(label: 'Urgent', insights: urgent),
                    if (suggestion.isNotEmpty)
                      _SeverityGroup(
                        label: 'Suggestions',
                        insights: suggestion,
                      ),
                    if (info.isNotEmpty)
                      _SeverityGroup(label: 'FYI', insights: info),
                  ],
                );
              }
              return ResponsivePage(
                bottomPadding: 32,
                children: [
                  header,
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _SeverityGroup(
                            label: 'Urgent',
                            insights: urgent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SeverityGroup(
                            label: 'Suggestions',
                            insights: suggestion,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SeverityGroup(
                            label: 'FYI',
                            insights: info,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The bento variant of the Insights data section — the SAME three severity
/// buckets ([_SeverityGroup]s over the same provider data), re-laid as
/// importance-weighted tiles instead of the 3-column dashboard. Only the
/// layout changes; the cards, snooze, and actions are untouched.
///
/// Empty buckets emit NO tile (vs. the desktop dashboard's "All clear."
/// filler) — a missing tile reads cleaner in a packed grid than an empty box.
class _InsightsBento extends StatelessWidget {
  const _InsightsBento({
    required this.urgent,
    required this.suggestion,
    required this.info,
  });

  final List<Insight> urgent;
  final List<Insight> suggestion;
  final List<Insight> info;

  @override
  Widget build(BuildContext context) {
    // Tune spans so the Wrap (1-D, left-to-right) packs into clean runs.
    // Urgent is the hero ("what matters most"): full-width on phone, 4-of-6
    // on desktop, two rows tall. Suggestions pairs beside it (2-of-6 ×2) to
    // complete the top desktop run; FYI banners full-width below.
    final tiles = <BentoTile>[
      if (urgent.isNotEmpty)
        BentoTile(
          id: 'urgent',
          span: const BentoSpan.hero(),
          child: _SeverityGroup(label: 'Urgent', insights: urgent),
        ),
      if (suggestion.isNotEmpty)
        BentoTile(
          id: 'suggestion',
          // Pairs beside the hero on desktop (2-of-6 ×2) to fill the top run;
          // a full-width band on phone/tablet. phone/desktop spans are the
          // defaults (2), so only tablet + rows are stated.
          span: const BentoSpan(tablet: 4, rows: 2),
          child: _SeverityGroup(label: 'Suggestions', insights: suggestion),
        ),
      if (info.isNotEmpty)
        BentoTile(
          id: 'info',
          span: const BentoSpan.wide(),
          child: _SeverityGroup(label: 'FYI', insights: info),
        ),
    ];

    return ResponsivePage(
      bottomPadding: 32,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ContentHeader(
            title: 'Insights',
            subtitle: 'Questions the system is surfacing from your data',
          ),
        ),
        const SizedBox(height: 12),
        BentoGrid(tiles: tiles),
      ],
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
      // Shrink-wrap vertically: a bento cell is min-height / unbounded-max
      // (docs/GRID.md), so a default mainAxisSize.max Column would try to
      // expand into unbounded height and throw. .min is also correct in the
      // non-bento paths (ListView child + IntrinsicHeight both honour it).
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // Wave 114: on the 3-column desktop dashboard, empty buckets
        // render "All clear" so the column doesn't read as broken.
        // On phone (single-column), the bucket header is hidden
        // upstream when empty, so this branch only fires at desktop.
        if (insights.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'All clear.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
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
                  onPressed: () => context.push(insight.actions.first.route),
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
                rest == 1 ? '1 more — see all' : '$rest more — see all',
              ),
            ),
          ),
      ],
    );
  }
}
