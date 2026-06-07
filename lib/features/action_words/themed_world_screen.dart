import 'dart:async';

import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/senses.dart';
import 'package:differentworld/features/action_words/themed_worlds.dart';
import 'package:differentworld/features/action_words/widgets/world_badge.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// **Different Worlds** — the program's standing worlds (Books, Movies,
/// Songs, Dreams, Space, Time), the bigger worlds the rooms step into. The
/// umbrella is *Different World*; the daily 3-verb Action Words world nests
/// inside whichever world a room is living in. Tap a world to see how to
/// *become it* (the senses) and what it's made of (the facets the room
/// builds: people, culture, a pretend map, tools, dreams). See
/// docs/WORLD.md.
class ThemedWorldScreen extends ConsumerWidget {
  const ThemedWorldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gold = WorldBadge.goldFor(theme);
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Different Worlds',
            subtitle: 'The worlds your rooms step into',
          ),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 720
                  ? 3
                  : c.maxWidth >= 480
                      ? 2
                      : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
                children: [
                  for (final w in kThemedWorlds)
                    _WorldCard(
                      world: w,
                      gold: gold,
                      onTap: () => _showWorld(context, w, gold),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showWorld(
    BuildContext context,
    ThemedWorld world,
    Color gold,
  ) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WorldSheet(world: world, gold: gold),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.gold,
    required this.onTap,
  });
  final ThemedWorld world;
  final Color gold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: gold.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(world.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      world.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      world.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _WorldSheet extends StatelessWidget {
  const _WorldSheet({required this.world, required this.gold});
  final ThemedWorld world;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(world.emoji, style: const TextStyle(fontSize: 56)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  world.name,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  world.tagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(label: 'Become it', gold: gold),
              for (final beat in world.senses) _SenseRow(beat: beat),
              const SizedBox(height: 16),
              _SectionLabel(label: 'What’s in this world', gold: gold),
              for (final facet in kWorldFacets) _FacetRow(facet: facet),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  // Capture the router BEFORE pop — the sheet's context
                  // deactivates the moment it closes (interaction rule #3).
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  unawaited(router.push('/action-words/activities'));
                },
                icon: const Icon(Icons.local_activity_outlined),
                label: const Text('Find activities for this world'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.gold});
  final String label;
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: gold, letterSpacing: 0.4),
      ),
    );
  }
}

class _SenseRow extends StatelessWidget {
  const _SenseRow({required this.beat});
  final SenseBeat beat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(beat.sense.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beat.sense.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(beat.prompt, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacetRow extends StatelessWidget {
  const _FacetRow({required this.facet});
  final WorldFacet facet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facet.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(facet.name, style: theme.textTheme.titleSmall),
                Text(
                  facet.prompt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
