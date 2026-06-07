import 'package:differentworld/features/action_words/verbs.dart';
import 'package:flutter/material.dart';

/// Shows a kid's picked verbs as LENSES — "how they'll do it today". The
/// same shared activity, seen through their three verbs: one activity, ten
/// experiences (docs/ACTION_WORDS.md). [verbIds] are the day's picks.
class VerbLensStrip extends StatelessWidget {
  const VerbLensStrip({required this.verbIds, this.accent, super.key});

  final List<String> verbIds;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accent ?? theme.colorScheme.primary;
    final verbs = verbsByIds(verbIds);
    if (verbs.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final v in verbs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(v.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  v.label.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: tint,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    v.lens,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
