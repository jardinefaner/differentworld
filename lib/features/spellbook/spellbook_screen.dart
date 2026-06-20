import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/world_arc.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/daily/daily_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/spellbook/spellbook_bento_setting.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
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
/// Two layouts over the SAME data: the stacked list (default) and a BENTO grid
/// (opt-in via `spellbookBentoProvider`) that spreads on a tablet. Gated on
/// `spellbookEnabledProvider` at the discovery layer.
class SpellbookScreen extends ConsumerWidget {
  const SpellbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bento = bentoEnabled(
      ref,
      perScreen: ref.watch(spellbookBentoProvider).value,
    );
    final trio = ref.watch(todaysDailyProvider);
    final world = ref.watch(currentWorldProvider);
    final arc = ref.watch(currentWorldArcProvider);

    final question = (trio.question?.payload['text'] as String?)?.trim();
    final project = arc?.missions.project.trim();

    // The three nav targets — shared by both layouts so they never drift.
    final navs = <_Spell>[
      _Spell(
        icon: Icons.wb_sunny_outlined,
        title: 'Today’s spell',
        subtitle: (question == null || question.isEmpty)
            ? 'The question, quote, and mission of the day'
            : question,
        route: '/daily',
      ),
      _Spell(
        icon: Icons.auto_stories_outlined,
        title: 'This week’s quest',
        subtitle: (project == null || project.isEmpty)
            ? 'One project, all week — open the world'
            : project,
        route: '/this-week',
      ),
      const _Spell(
        icon: Icons.auto_graph_outlined,
        title: 'Your story so far',
        subtitle: 'Everything you do is becoming the tale',
        route: '/this-week',
      ),
    ];

    return EdgeScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const ContentHeader(
              title: 'Your spellbook',
              subtitle: 'A little magic, every day',
            ),
            if (bento)
              BentoGrid(
                tiles: [
                  BentoTile(
                    id: 'cover',
                    span: const BentoSpan.wide(),
                    child: _Cover(world: world),
                  ),
                  for (var i = 0; i < navs.length; i++)
                    BentoTile(
                      id: 'spell-$i',
                      // The first two sit side-by-side on a phone; the story
                      // spans the row.
                      span: i < 2
                          ? const BentoSpan(phone: 1)
                          : const BentoSpan.wide(),
                      child: _SpellTile(spell: navs[i]),
                    ),
                ],
              )
            else ...[
              _Cover(world: world),
              const SizedBox(height: 18),
              for (var i = 0; i < navs.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                FeatureCard(
                  leading: Icon(
                    navs[i].icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: navs[i].title,
                  subtitle: navs[i].subtitle,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(navs[i].route),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// One spell — a nav target shared by the list + bento layouts.
class _Spell {
  const _Spell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

/// The world cover banner — the warm, host-present header that sets the world.
class _Cover extends StatelessWidget {
  const _Cover({required this.world});

  final CurriculumWorld? world;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(world?.emoji ?? '✨', style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  world == null
                      ? 'A world of magic'
                      : 'This week: ${world!.name}',
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
    );
  }
}

/// A spell as a bento tile — tappable, shrink-wrapping (a bento cell is
/// unbounded-max, so NO Expanded/Spacer; see docs/GRID.md).
class _SpellTile extends StatelessWidget {
  const _SpellTile({required this.spell});

  final _Spell spell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(spell.route),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(spell.icon, color: scheme.primary),
              const SizedBox(height: 10),
              Text(
                spell.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                spell.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
