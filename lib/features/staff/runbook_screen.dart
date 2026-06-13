import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/staff/runbook.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
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
    return EdgeScaffold(
      body: momentsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the runbook',
          onRetry: () => ref.invalidate(staffRunbookProvider),
        ),
        data: (moments) => ResponsivePage(
          children: [
            const ContentHeader(
              title: 'The day, moment by moment',
              subtitle:
                  'Lead · Helper · If it breaks — any adult can run the '
                  'next hour',
            ),
            for (final m in moments) _MomentCard(moment: m),
          ],
        ),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});
  final RunbookMoment moment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
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
