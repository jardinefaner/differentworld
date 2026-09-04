import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/widgets/thinking_game_blocks.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';

/// Open one Big Thinking game as a glass sheet — play → name → bridge →
/// question. Used from the character-sheet sections ("the game under this")
/// so every RPG system can open its game inline.
Future<void> showThinkingGameSheet(BuildContext context, ThinkingGame game) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ThinkingGameSheet(game: game),
  );
}

class _ThinkingGameSheet extends StatelessWidget {
  const _ThinkingGameSheet({required this.game});
  final ThinkingGame game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(game.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    game.concept,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            if (game.meaning.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                game.meaning,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ThinkingBeat(label: '1 · Play it', body: game.play),
            ThinkingBeat(label: '2 · Name it', body: game.name),
            const ThinkingBeatLabel('3 · Where else'),
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
                    Expanded(child: Text(b, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            ThinkingQuestionCard(question: game.question),
          ],
        ),
      ),
    );
  }
}
