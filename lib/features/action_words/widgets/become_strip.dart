import 'package:differentworld/features/action_words/senses.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:flutter/material.dart';

/// The sensory "become it" for a world — how the culture becomes an
/// activity: move like it, sound like it, feel it. A calm few cues under
/// the reveal so discovering a world flows straight into *doing* it.
class BecomeStrip extends StatelessWidget {
  const BecomeStrip({required this.match, this.accent, super.key});

  final WorldMatch match;

  /// Optional accent (the reveal passes gold). Defaults to the theme's
  /// primary.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = accent ?? theme.colorScheme.primary;
    final beats = becomeFor(match);
    if (beats.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'BECOME IT',
          style: theme.textTheme.labelSmall?.copyWith(
            color: gold,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final b in beats)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(b.sense.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    b.prompt,
                    textAlign: TextAlign.center,
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
