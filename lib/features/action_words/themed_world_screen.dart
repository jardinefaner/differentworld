import 'dart:async';

import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/themed_worlds.dart';
import 'package:differentworld/features/action_words/widgets/world_sections.dart';
import 'package:differentworld/features/action_words/worksheet_pdf.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/catalog_card.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **Different Worlds** — the 10-week "If You Built a World" journey
/// (Me → Stories → Nature → Water → Music → Space → Dreams → Time →
/// Feelings → Us). Each world is the bigger world a week lives in; the daily
/// 3-verb Action Words pick nests inside it. Tap a world for its ten facets,
/// featured verbs, Watch → Do videos, and activities. Content is the
/// canonical curriculum (docs/curriculum/). See docs/WORLD.md.
class ThemedWorldScreen extends ConsumerWidget {
  const ThemedWorldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldsAsync = ref.watch(curriculumWorldsProvider);
    final worlds = worldsAsync.value ?? const <CurriculumWorld>[];
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the ten worlds re-lay as a denser bento
    // grid over the SAME provider; off keeps the existing catalog grid.
    final bento = bentoEnabled(ref, perScreen: null);

    return EdgeScaffold(
      actions: [
        if (worlds.isNotEmpty)
          IconButton(
            tooltip: 'Print all worksheets',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => unawaited(printAllWorksheets(worlds)),
          ),
        const SyncStatusIndicator(),
      ],
      body: worldsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the worlds',
          onRetry: () => ref.invalidate(curriculumWorldsProvider),
        ),
        data: (worlds) => ResponsivePage(
          children: [
            const ContentHeader(
              title: 'Different Worlds',
              subtitle: '10 weeks · 10 worlds · 1 Different World',
            ),
            const SizedBox(height: 4),
            if (bento)
              // Each world card is SHORT → `phone: 1` packs them 2-up on a
              // phone (the grid read), 2-up on tablet, 3-up on desktop. The
              // [CatalogCard] already shrink-wraps (mainAxisSize.min, no
              // Spacer/Expanded), so it's safe in the min-height/unbounded
              // bento cell with no fixed-height wrapper (docs/GRID.md). Tap
              // still opens the world sheet — same behavior as the flat grid.
              BentoGrid(
                tiles: [
                  for (final w in worlds)
                    BentoTile(
                      id: 'world-${w.id}',
                      span: const BentoSpan(phone: 1),
                      child: _WorldCard(
                        world: w,
                        onTap: () => _showWorld(context, w),
                      ),
                    ),
                ],
              )
            else
              CatalogGrid(
                children: [
                  for (final w in worlds)
                    _WorldCard(world: w, onTap: () => _showWorld(context, w)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWorld(BuildContext context, CurriculumWorld world) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WorldSheet(world: world),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.world, required this.onTap});
  final CurriculumWorld world;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CatalogCard(
      leading: CatalogIcon.emoji(world.emoji),
      title: world.name,
      titleWidget: EntityLink(
        entity: EntityRef(
          kind: EntityKind.world,
          id: world.id,
          label: world.name,
        ),
        padded: false,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: world.tagline,
      chips: [
        CatalogChip(
          'Week ${world.week}',
          background: world.color.withValues(alpha: 0.16),
          foreground: world.color,
        ),
      ],
      onTap: onTap,
    );
  }
}

class _WorldSheet extends StatelessWidget {
  const _WorldSheet({required this.world});
  final CurriculumWorld world;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = world.color;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero
              Center(
                child: Text(world.emoji, style: const TextStyle(fontSize: 52)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Week ${world.week}',
                  style: theme.textTheme.labelMedium?.copyWith(color: accent),
                ),
              ),
              Center(
                child: Text(
                  world.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  world.tagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '“${world.question}”',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Featured verbs
              WorldVerbsSection(world: world, accent: accent),
              if (world.verbsNote.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  world.verbsNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Watch -> Do
              if (world.videos.isNotEmpty) ...[
                WorldWatchDoSection(world: world, accent: accent),
                const SizedBox(height: 18),
              ],

              // Activities
              if (world.activities.isNotEmpty) ...[
                SectionLabel(text: 'Activities', accent: accent),
                for (final a in world.activities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•  ',
                          style: TextStyle(color: accent, height: 1.4),
                        ),
                        Expanded(
                          child: Text(a, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
              ],

              // The ten facets
              SectionLabel(text: 'What’s in this world', accent: accent),
              for (final facet in kWorldFacets)
                if ((world.facets[facet.id] ?? '').isNotEmpty)
                  _FacetRow(
                    facet: facet,
                    content: world.facets[facet.id]!,
                  ),

              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: accent),
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  final verbs = world.featuredVerbs.join(',');
                  unawaited(
                    router.push('/action-words/activities?verbs=$verbs'),
                  );
                },
                icon: const Icon(Icons.local_activity_outlined),
                label: const Text('Activities for these verbs'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  unawaited(router.push('/present-world/${world.id}'));
                },
                icon: const Icon(Icons.cast),
                label: const Text('Cast to the room'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => unawaited(printWorldWorksheets(world)),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print worksheets'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacetRow extends StatelessWidget {
  const _FacetRow({required this.facet, required this.content});
  final WorldFacet facet;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facet.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(facet.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
