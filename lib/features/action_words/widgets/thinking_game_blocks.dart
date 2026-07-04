import 'package:flutter/material.dart';

/// Shared building blocks for rendering a Big Thinking game's
/// play → name → bridge → question narrative. Used by both the `/thinking`
/// deck cards (`ThinkingScreen`) and the character-sheet glass sheet
/// (`showThinkingGameSheet`) so the two surfaces stay pixel-identical.

/// One numbered beat — an uppercase label over its body text.
class ThinkingBeat extends StatelessWidget {
  const ThinkingBeat({required this.label, required this.body, super.key});
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ThinkingBeatLabel(label),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// The small uppercase primary-colored beat label ("1 · PLAY IT").
class ThinkingBeatLabel extends StatelessWidget {
  const ThinkingBeatLabel(this.text, {super.key});
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

/// The closing beat — "4 · THE QUESTION" on a tertiary-container card.
/// The question with no answer, which goes on the Wall to grow answers.
class ThinkingQuestionCard extends StatelessWidget {
  const ThinkingQuestionCard({required this.question, super.key});
  final String question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
            '“$question”',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
