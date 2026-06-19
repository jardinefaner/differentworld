import 'package:differentworld/features/action_words/world_arc.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/daily/daily_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/spellbook` — the **Spellbook** home (docs/VISION.md 2026-06-19): a
/// magic-framed surface that GATHERS what already exists into one place the
/// room opens each day — today's ritual (the Daily), this week's project (the
/// live world arc), and the unfolding story (the journey). "A world of magic"
/// as a container, RPG-as-utility — it builds nothing new under the hood, it
/// just opens the spellbook on the day.
///
/// Gated on `spellbookEnabledProvider` at the discovery layer.
class SpellbookScreen extends ConsumerWidget {
  const SpellbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trio = ref.watch(todaysDailyProvider);
    final world = ref.watch(currentWorldProvider);
    final arc = ref.watch(currentWorldArcProvider);

    final question = (trio.question?.payload['text'] as String?)?.trim();
    final project = arc?.missions.project.trim();

    return EdgeScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const ContentHeader(
              title: 'Your spellbook',
              subtitle: 'A little magic, every day',
            ),
            // The cover — a warm, host-present banner that sets the world.
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        world?.emoji ?? '✨',
                        style: const TextStyle(fontSize: 30),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          world == null
                              ? 'A world of magic'
                              : 'This week: ${world.name}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    world?.tagline ??
                        'Open it each day — cast a little more of your story.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            FeatureCard(
              leading: Icon(Icons.wb_sunny_outlined, color: scheme.primary),
              title: 'Today’s spell',
              subtitle: (question == null || question.isEmpty)
                  ? 'The question, quote, and mission of the day'
                  : question,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/daily'),
            ),
            const SizedBox(height: 10),
            FeatureCard(
              leading: Icon(Icons.auto_stories_outlined, color: scheme.primary),
              title: 'This week’s quest',
              subtitle: (project == null || project.isEmpty)
                  ? 'One project, all week — open the world'
                  : project,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/this-week'),
            ),
            const SizedBox(height: 10),
            FeatureCard(
              leading: Icon(Icons.auto_graph_outlined, color: scheme.primary),
              title: 'Your story so far',
              subtitle: 'Everything you do is becoming the tale',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/this-week'),
            ),
          ],
        ),
      ),
    );
  }
}
