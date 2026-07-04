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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/print` — the **printable toolkit.** The offline/physical layer: the app
/// generates the binder pages it uniquely has data for (the verbs, the
/// verb→job map, the timer spells), so a sub can walk in and run the room from
/// paper. Word-forward (Helvetica can't draw emoji); the personalized capstone
/// of this binder is the per-child Summer Book (from a kid's Book screen).
///
/// Every item honours the **copies** stepper (baked into the file) and goes out
/// the platform-right way — DOWNLOAD on web, the print dialog on native.
class PrintToolkitScreen extends ConsumerStatefulWidget {
  const PrintToolkitScreen({super.key});

  @override
  ConsumerState<PrintToolkitScreen> createState() => _PrintToolkitScreenState();
}

class _PrintToolkitScreenState extends ConsumerState<PrintToolkitScreen> {
  int _copies = 1;

  void _setCopies(int v) => setState(() => _copies = v.clamp(1, 60));

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Printable toolkit',
            subtitle: 'Laminate once, use all summer — generates offline',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              kIsWeb
                  ? "Word-forward cards (printing can't draw emoji — sticker "
                        'them on after). Each one downloads as a PDF.'
                  : "Word-forward cards (printing can't draw emoji — sticker "
                        'them on after).',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _CopiesStepper(copies: _copies, onChanged: _setCopies),
          const SizedBox(height: 12),
          FeatureCard(
            leading: const Icon(Icons.style_outlined),
            title: 'Verb cards',
            subtitle: '12 full-page cards — the morning basket',
            onTap: () => unawaited(printVerbCards(copies: _copies)),
          ),
          FeatureCard(
            leading: const Icon(Icons.timer_outlined),
            title: 'Timer spell cards',
            subtitle: 'FREEZE · MOVE · CREATE · SHARE · WONDER',
            onTap: () => unawaited(printTimerSpellCards(copies: _copies)),
          ),
          FeatureCard(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: 'Spell word cards',
            subtitle: '30 words to earn — word front, meaning + gesture back',
            onTap: _withSpellWords,
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
                _stillLoading('Still loading');
                return;
              }
              unawaited(printVerbJobReference(roles, copies: _copies));
            },
          ),
          FeatureCard(
            leading: const Icon(Icons.theater_comedy_outlined),
            title: 'Verb gesture guide',
            subtitle: 'How to act out each verb (closing game)',
            onTap: () => unawaited(printGestureGuide(copies: _copies)),
          ),
          FeatureCard(
            leading: const Icon(Icons.healing_outlined),
            title: 'Reference card',
            subtitle: 'The repair script + the mood-weather scale',
            onTap: () => unawaited(printReferenceCard(copies: _copies)),
          ),
          FeatureCard(
            leading: const Icon(Icons.public_outlined),
            title: 'World reveal cards',
            subtitle: 'One per world — hold up, flip, reveal',
            onTap: () => _withWorlds(printWorldRevealCards),
          ),
          FeatureCard(
            leading: const Icon(Icons.article_outlined),
            title: 'World summary posters',
            subtitle: 'Name · question · verbs · rules, one per world',
            onTap: () => _withWorlds(printWorldSummaryCards),
          ),
          FeatureCard(
            leading: const Icon(Icons.help_outline),
            title: 'Wall question deck',
            subtitle: '50 day-by-day questions — one poster per day',
            onTap: _withBlocks,
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

  void _stillLoading(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what — try again.')),
    );
  }

  /// Generate a curriculum-driven PDF, guarding the not-yet-loaded case with a
  /// snackbar so the tap is never a silent no-op.
  void _withWorlds(
    Future<bool> Function(List<CurriculumWorld>, {int copies}) gen,
  ) {
    final worlds =
        ref.read(curriculumWorldsProvider).value ?? const <CurriculumWorld>[];
    if (worlds.isEmpty) {
      _stillLoading('Worlds still loading');
      return;
    }
    unawaited(gen(worlds, copies: _copies));
  }

  void _withSpellWords() {
    final words = ref.read(spellWordsProvider).value ?? const <SpellWord>[];
    if (words.isEmpty) {
      _stillLoading('Words still loading');
      return;
    }
    unawaited(printSpellWordCards(words, copies: _copies));
  }

  void _withBlocks() {
    final blocks = ref.read(worldBlocksProvider).value ?? const <WorldBlock>[];
    if (blocks.isEmpty) {
      _stillLoading('Journey still loading');
      return;
    }
    unawaited(printWallQuestionDeck(blocks, copies: _copies));
  }
}

/// "How many copies" — baked into the generated PDF so it works on the web
/// download path too (where there's no print-dialog copies field until the
/// file's opened).
class _CopiesStepper extends StatelessWidget {
  const _CopiesStepper({required this.copies, required this.onChanged});

  final int copies;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How many copies', style: theme.textTheme.titleMedium),
                  Text(
                    copies == 1
                        ? 'One of each'
                        : '$copies of each — e.g. one per child',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Fewer',
              onPressed: copies > 1 ? () => onChanged(copies - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$copies',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'More',
              onPressed: copies < 60 ? () => onChanged(copies + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
