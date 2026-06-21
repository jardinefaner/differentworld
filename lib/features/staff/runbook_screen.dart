import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/staff/runbook.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/runbook` — **the day, moment by moment, for the grown-ups.** The staff
/// twin of "Play today": each moment opens to three lanes — LEAD, HELPER, and
/// IF IT BREAKS — so any adult can run the next hour without hunting. Pure
/// reference content (bundled JSON); no per-room state.
class RunbookScreen extends ConsumerWidget {
  const RunbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentsAsync = ref.watch(staffRunbookProvider);
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the day's moments re-pack as a
    // responsive bento grid over the SAME provider data; off keeps the
    // existing single-column list of expandable moments.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      body: momentsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the runbook',
          onRetry: () => ref.invalidate(staffRunbookProvider),
        ),
        data: (moments) =>
            bento ? _bentoBody(moments) : _flatBody(moments),
      ),
    );
  }

  /// The default layout — header + a single-column list of expandable
  /// moment cards.
  Widget _flatBody(List<RunbookMoment> moments) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'The day, moment by moment',
          subtitle: 'Lead · Helper · If it breaks — any adult can run the '
              'next hour',
        ),
        for (final m in moments) _MomentCard(moment: m),
      ],
    );
  }

  /// The bento variant — SAME moments, re-packed as a responsive grid. The
  /// header stays full-width. Each moment is an expandable card that's
  /// **full-width on a phone** (its expanded Lead / Helper / If-it-breaks
  /// lanes are narrative and need the width to read), then **2-up on a
  /// tablet, 3-up on desktop** where the room exists. The grid is min-height
  /// (docs/GRID.md), so a card growing on expand never clips — it leaves the
  /// run ragged, which is the intended trade for not clipping text.
  Widget _bentoBody(List<RunbookMoment> moments) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'The day, moment by moment',
          subtitle: 'Lead · Helper · If it breaks — any adult can run the '
              'next hour',
        ),
        const SizedBox(height: 4),
        BentoGrid(
          tiles: [
            for (final m in moments)
              BentoTile(
                id: 'runbook-${m.time}-${m.name}',
                // The default span (phone 2 / tablet 2 / desktop 2 of the
                // 2/4/6-column grid) lands exactly where this content wants:
                // full-width on a phone (narrative on expand), 2-up on a
                // tablet, 3-up on desktop.
                span: const BentoSpan(),
                child: _MomentCard(moment: m, inGrid: true),
              ),
          ],
        ),
      ],
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment, this.inGrid = false});
  final RunbookMoment moment;

  /// When true the card is a bento grid cell — drop the bottom margin (the
  /// grid owns the inter-tile gap) and don't paint a trailing gap.
  final bool inGrid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: inGrid
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Text(moment.emoji, style: const TextStyle(fontSize: 26)),
        title: Text(
          moment.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          moment.time,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Lane(
            label: 'Lead teacher',
            body: moment.lead,
            tone: theme.colorScheme.primary,
          ),
          _Lane(
            label: 'Helper',
            body: moment.helper,
            tone: AppColors.growthOf(theme),
          ),
          _Lane(
            label: 'If it breaks',
            body: moment.ifItBreaks,
            tone: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({required this.label, required this.body, required this.tone});
  final String label;
  final String body;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: tone.withValues(alpha: 0.5), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
