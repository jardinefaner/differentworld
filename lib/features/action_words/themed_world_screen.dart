import 'dart:async';

import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/themed_worlds.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worksheet_pdf.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
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
            for (final w in worlds)
              _WorldCard(world: w, onTap: () => _showWorld(context, w)),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: world.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(world.emoji, style: const TextStyle(fontSize: 38)),
                    const SizedBox(height: 2),
                    Text(
                      'Week ${world.week}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: world.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
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
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '“${world.question}”',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),

              // Featured verbs
              _Label(text: 'This week’s verbs', accent: accent),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in world.featuredVerbs)
                    if (verbById(id) case final v?)
                      Chip(
                        label: Text('${v.emoji} ${v.label}'),
                        visualDensity: VisualDensity.compact,
                      ),
                ],
              ),
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
                _Label(text: 'Watch → Do', accent: accent),
                for (final v in world.videos) _VideoRow(video: v),
                const SizedBox(height: 6),
                Text(
                  kScreenTimeRules.first,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Activities
              if (world.activities.isNotEmpty) ...[
                _Label(text: 'Activities', accent: accent),
                for (final a in world.activities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ',
                            style: TextStyle(color: accent, height: 1.4)),
                        Expanded(
                          child: Text(a, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
              ],

              // The ten facets
              _Label(text: 'What’s in this world', accent: accent),
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

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.accent});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: accent, letterSpacing: 0.4),
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  const _VideoRow({required this.video});
  final WorldVideo video;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.play_circle_outline, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${video.title}  ·  ${video.minutes} min',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '→ ${video.after}',
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
