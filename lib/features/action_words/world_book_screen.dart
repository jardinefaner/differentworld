import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/catalog_card.dart';
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the invented worlds re-lay as a denser
    // bento grid over the SAME provider; off keeps the existing catalog grid.
    final bento = bentoEnabled(ref, perScreen: null);

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
              message:
                  'When a child’s three words make a brand-new combo, '
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
              if (bento)
                // Each world card is SHORT → `phone: 1` packs them 2-up on a
                // phone (the grid read), 2-up on tablet, 3-up on desktop. The
                // [CatalogCard] already shrink-wraps (mainAxisSize.min, no
                // Spacer/Expanded), so it's safe in the min-height/unbounded
                // bento cell with no fixed-height wrapper (docs/GRID.md).
                BentoGrid(
                  tiles: [
                    for (final w in invented)
                      BentoTile(
                        id: 'world-${w.name}',
                        span: const BentoSpan(phone: 1),
                        child: _InventedCard(world: w, gold: gold),
                      ),
                  ],
                )
              else
                CatalogGrid(
                  children: [
                    for (final w in invented)
                      _InventedCard(world: w, gold: gold),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InventedCard extends StatelessWidget {
  const _InventedCard({required this.world, required this.gold});

  final InventedWorld world;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final verbs = verbsByIds(world.verbs.toList());
    final verbLine = [
      for (final v in verbs) '${v.emoji} ${v.label}',
    ].join('  ');
    return CatalogCard(
      leading: const CatalogIcon.emoji('🌟'),
      title: world.name,
      subtitle: verbLine,
      chips: [
        CatalogChip(
          world.count == 1 ? '1 day' : '${world.count} days',
          background: gold.withValues(alpha: 0.16),
          foreground: gold,
        ),
      ],
    );
  }
}
