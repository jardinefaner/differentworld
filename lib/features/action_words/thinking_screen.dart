import 'dart:async';

import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/thinking` — the **Big Thinking** deck. Play → name → bridge → question.
/// Each game teaches a concept through the body, gives it a one-word name
/// (the spell), bridges it out to the world, and ends with a question that
/// has no answer — which you put on the Wall to grow answers all week.
class ThinkingScreen extends ConsumerWidget {
  const ThinkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(thinkingGamesProvider);
    return EdgeScaffold(
      body: gamesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the thinking games',
          onRetry: () => ref.invalidate(thinkingGamesProvider),
        ),
        data: (games) {
          // Lead with this week's WORLD game(s); the rest of the deck follows.
          final weekGames = ref.watch(thisWeekThinkingProvider);
          final world = ref.watch(currentWorldProvider);
          final weekIds = {for (final g in weekGames) g.id};
          final rest = [
            for (final g in games)
              if (!weekIds.contains(g.id)) g,
          ];
          return ResponsivePage(
            children: [
              const ContentHeader(
                title: 'Big Thinking',
                subtitle:
                    'Play it · name it · use it everywhere · then the '
                    'question with no answer',
              ),
              if (weekGames.isNotEmpty) ...[
                _SectionLabel(
                  world == null ? 'This week' : 'This week · ${world.name}',
                ),
                for (final g in weekGames) _GameCard(game: g),
                const _SectionLabel('The whole deck'),
              ],
              for (final g in rest) _GameCard(game: g),
            ],
          );
        },
      ),
    );
  }
}

class _GameCard extends ConsumerWidget {
  const _GameCard({required this.game});
  final ThinkingGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Text(game.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(
          game.concept,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        subtitle: Text(game.meaning),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Beat(label: '1 · Play it', body: game.play, accent: theme),
          _Beat(label: '2 · Name it', body: game.name, accent: theme),
          const _Label('3 · Where else'),
          for (final b in game.bridge)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '↳  ',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                  Expanded(
                    child: Text(b, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          // The question — the one with no answer.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '4 · THE QUESTION',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer.withValues(
                      alpha: 0.7,
                    ),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '“${game.question}”',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _toWall(context, ref),
              icon: const Icon(Icons.push_pin_outlined, size: 18),
              label: const Text('Put it on the Wall'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toWall(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final world = ref.read(currentWorldProvider);
    if (world == null) {
      // No live world to pin to — copy it so the teacher can use it anyway.
      await Clipboard.setData(ClipboardData(text: game.question));
      messenger.showSnackBar(
        const SnackBar(content: Text('Question copied')),
      );
      return;
    }
    await ref
        .read(entryActionsProvider)
        .createWallNote(
          text: game.question,
          worldId: world.id,
          noteType: 'free',
        );
    messenger.showSnackBar(
      SnackBar(content: Text('Posted to ${world.name}’s Wall')),
    );
  }
}

class _Beat extends StatelessWidget {
  const _Beat({required this.label, required this.body, required this.accent});
  final String label;
  final String body;
  final ThemeData accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          Text(body, style: accent.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// A deck section divider ("THIS WEEK · WORLD OF WATER", "THE WHOLE DECK").
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
