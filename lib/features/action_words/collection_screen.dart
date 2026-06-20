import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/widgets/world_badge.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A child's Action Words collection over time — the worlds they've
/// revealed (bright, with a count) vs the ones still grey silhouettes,
/// their most-practiced verbs as bars, and the emerging title
/// ("The Owl Who Listens"). The "collect" payoff (brief #8).
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gold = WorldBadge.goldFor(theme);
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    final firstName = subject?.firstName ?? 'This child';
    final collection = ref.watch(actionWordsCollectionProvider(subjectId)).value;

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: collection == null
          ? const LoadingSlot()
          : collection.dayCount == 0
              ? EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'No worlds yet',
                  message: 'Pick $firstName’s three words each day — the '
                      'worlds they reveal collect here.',
                )
              : ResponsivePage(
                  children: [
                    ContentHeader(
                      title: '$firstName’s worlds',
                      subtitle: collection.dayCount == 1
                          ? '1 day'
                          : '${collection.dayCount} days',
                    ),
                    if (collection.emergingTitle != null) ...[
                      _TitleBanner(title: collection.emergingTitle!, gold: gold),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      '${collection.collectedWorlds} of ${kNamedWorlds.length} '
                      'worlds',
                      style: theme.textTheme.labelLarge?.copyWith(color: gold),
                    ),
                    const SizedBox(height: 8),
                    _WorldsGrid(counts: collection.worldCounts, gold: gold),
                    const SizedBox(height: 24),
                    Text(
                      'Most practiced',
                      style: theme.textTheme.labelLarge?.copyWith(color: gold),
                    ),
                    const SizedBox(height: 8),
                    _VerbBars(totals: collection.verbTotals, gold: gold),
                  ],
                ),
    );
  }
}

class _TitleBanner extends StatelessWidget {
  const _TitleBanner({required this.title, required this.gold});
  final String title;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            'Becoming',
            style: theme.textTheme.labelSmall?.copyWith(
              color: gold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldsGrid extends StatelessWidget {
  const _WorldsGrid({required this.counts, required this.gold});
  final Map<String, int> counts;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 520 ? 5 : 4;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: [
            for (final w in kNamedWorlds)
              _WorldCell(world: w, count: counts[w.id] ?? 0, gold: gold),
          ],
        );
      },
    );
  }
}

class _WorldCell extends StatelessWidget {
  const _WorldCell({
    required this.world,
    required this.count,
    required this.gold,
  });
  final World world;
  final int count;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collected = count > 0;
    return Tooltip(
      message: '${world.name} · ${world.title}'
          '${collected ? ' ×$count' : ' (not yet)'}',
      child: Opacity(
        opacity: collected ? 1 : 0.32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Text(world.emoji, style: const TextStyle(fontSize: 34)),
                if (count > 1)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: gold,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '×$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          // Readable on the content-driven gold badge (adapts
                          // to luminance) instead of a hardcoded black.
                          color: AppColors.onAccent(gold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              world.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerbBars extends StatelessWidget {
  const _VerbBars({required this.totals, required this.gold});
  final Map<String, int> totals;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (totals.isEmpty) {
      return Text(
        'Nothing practiced yet.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final max = totals.values.fold<int>(1, (a, b) => b > a ? b : a);
    final sorted = totals.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return Column(
      children: [
        for (final e in sorted)
          if (verbById(e.key) case final v?)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text('${v.emoji} ${v.label}'),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: e.value / max,
                        minHeight: 10,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(gold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.value}', style: theme.textTheme.labelMedium),
                ],
              ),
            ),
      ],
    );
  }
}
