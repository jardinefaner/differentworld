import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The class's **world book** — the worlds your program *invented* (fresh
/// combos a kid named). This is the "create their own worlds, growth
/// unhidden" surface: the fixed ~40 are just the starter substrate; the
/// real culture is what each room builds and keeps (docs/ACTION_WORDS.md).
class WorldBookScreen extends ConsumerWidget {
  const WorldBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gold = AppColors.goldOf(theme);
    final async = ref.watch(inventedWorldsProvider);

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: async.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the world book',
          onRetry: () => ref.invalidate(inventedWorldsProvider),
        ),
        data: (invented) {
          if (invented.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No invented worlds yet',
              message: 'When a child’s three words make a brand-new combo, '
                  'name it on the reveal — it lives here as one of your '
                  'class’s own worlds.',
            );
          }
          final days = invented.fold<int>(0, (a, w) => a + w.count);
          return ResponsivePage(
            children: [
              ContentHeader(
                title: 'Our worlds',
                subtitle: invented.length == 1
                    ? '1 world your class invented'
                    : '${invented.length} worlds your class invented',
              ),
              Text(
                '${kNamedWorlds.length} starter worlds · '
                '${invented.length} invented · $days days',
                style: theme.textTheme.labelMedium?.copyWith(color: gold),
              ),
              const SizedBox(height: 12),
              for (final w in invented)
                _InventedTile(world: w, gold: gold),
            ],
          );
        },
      ),
    );
  }
}

class _InventedTile extends StatelessWidget {
  const _InventedTile({required this.world, required this.gold});

  final InventedWorld world;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Text('🌟', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    world.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final v in verbsByIds(world.verbs.toList()))
                        Text(
                          '${v.emoji} ${v.label}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                world.count == 1 ? '1 day' : '${world.count} days',
                style: theme.textTheme.labelSmall?.copyWith(color: gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
