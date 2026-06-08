import 'dart:async';

import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/spell_words.dart';
import 'package:differentworld/features/action_words/verb_roles.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/toolkit/toolkit_pdf.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/print` — the **printable toolkit.** The offline/physical layer: the app
/// generates the binder pages it uniquely has data for (the verbs, the
/// verb→job map, the timer spells), so a sub can walk in and run the room from
/// paper. Word-forward (Helvetica can't draw emoji); the personalized capstone
/// of this binder is the per-child Summer Book (from a kid's Book screen).
class PrintToolkitScreen extends ConsumerWidget {
  const PrintToolkitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EdgeScaffold(
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Printable toolkit',
            subtitle: 'Laminate once, use all summer — generates offline',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Word-forward cards (printing can't draw emoji — sticker them "
              "on after). The personalized page is each child's Summer Book.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FeatureCard(
            leading: const Icon(Icons.style_outlined),
            title: 'Verb cards',
            subtitle: '12 full-page cards — the morning basket',
            onTap: () => unawaited(printVerbCards()),
          ),
          FeatureCard(
            leading: const Icon(Icons.timer_outlined),
            title: 'Timer spell cards',
            subtitle: 'FREEZE · MOVE · CREATE · SHARE · WONDER',
            onTap: () => unawaited(printTimerSpellCards()),
          ),
          FeatureCard(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: 'Spell word cards',
            subtitle: '30 words to earn — word front, meaning + gesture back',
            onTap: () => _withSpellWords(context, ref),
          ),
          FeatureCard(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: 'Verb → job reference',
            subtitle: 'Which job each verb pick becomes',
            onTap: () {
              final roles =
                  ref.read(verbRolesProvider).value ??
                  const <String, VerbRole>{};
              if (roles.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Still loading — try again.')),
                );
                return;
              }
              unawaited(printVerbJobReference(roles));
            },
          ),
          FeatureCard(
            leading: const Icon(Icons.theater_comedy_outlined),
            title: 'Verb gesture guide',
            subtitle: 'How to act out each verb (closing game)',
            onTap: () => unawaited(printGestureGuide()),
          ),
          FeatureCard(
            leading: const Icon(Icons.healing_outlined),
            title: 'Reference card',
            subtitle: 'The repair script + the mood-weather scale',
            onTap: () => unawaited(printReferenceCard()),
          ),
          FeatureCard(
            leading: const Icon(Icons.public_outlined),
            title: 'World reveal cards',
            subtitle: 'One per world — hold up, flip, reveal',
            onTap: () => _withWorlds(context, ref, printWorldRevealCards),
          ),
          FeatureCard(
            leading: const Icon(Icons.article_outlined),
            title: 'World summary posters',
            subtitle: 'Name · question · verbs · rules, one per world',
            onTap: () => _withWorlds(context, ref, printWorldSummaryCards),
          ),
          FeatureCard(
            leading: const Icon(Icons.help_outline),
            title: 'Wall question deck',
            subtitle: '50 day-by-day questions — one poster per day',
            onTap: () => _withBlocks(context, ref),
          ),
          const SizedBox(height: 8),
          FeatureCard(
            leading: const Icon(Icons.menu_book_outlined),
            title: 'The runbook',
            subtitle: 'The day moment-by-moment — for the sub who walked in',
            onTap: () => context.push('/runbook'),
          ),
        ],
      ),
    );
  }

  /// Generate a curriculum-driven PDF, guarding the not-yet-loaded case with a
  /// snackbar so the tap is never a silent no-op.
  void _withWorlds(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function(List<CurriculumWorld>) gen,
  ) {
    final worlds =
        ref.read(curriculumWorldsProvider).value ?? const <CurriculumWorld>[];
    if (worlds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worlds still loading — try again.')),
      );
      return;
    }
    unawaited(gen(worlds));
  }

  void _withSpellWords(BuildContext context, WidgetRef ref) {
    final words = ref.read(spellWordsProvider).value ?? const <SpellWord>[];
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Words still loading — try again.')),
      );
      return;
    }
    unawaited(printSpellWordCards(words));
  }

  void _withBlocks(BuildContext context, WidgetRef ref) {
    final blocks = ref.read(worldBlocksProvider).value ?? const <WorldBlock>[];
    if (blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journey still loading — try again.')),
      );
      return;
    }
    unawaited(printWallQuestionDeck(blocks));
  }
}
