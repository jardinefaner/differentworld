import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:flutter/material.dart';

/// Renders the world a combo reveals — the emoji, name, archetype title,
/// and (optionally) the 3 verbs. Handles the *fresh* case (a new world the
/// kid names) too. Reused by the pick preview, the reveal, and the
/// collection.
class WorldBadge extends StatelessWidget {
  const WorldBadge({
    required this.match,
    this.freshName,
    this.emojiSize = 64,
    this.showVerbs = true,
    super.key,
  });

  final WorldMatch match;

  /// A kid-chosen name for a fresh world; shown instead of "A new world".
  final String? freshName;
  final double emojiSize;
  final bool showVerbs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = _gold(theme);
    final world = match.world;

    final String emoji;
    final String name;
    final String subtitle;
    if (world != null) {
      emoji = world.emoji;
      name = world.name;
      subtitle = world.title;
    } else {
      emoji = '🌟';
      name = (freshName == null || freshName!.isEmpty)
          ? 'A new world'
          : freshName!;
      subtitle = 'You get to name it';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: emojiSize)),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(color: gold),
        ),
        if (match.kind == WorldMatchKind.closest) ...[
          const SizedBox(height: 4),
          Text(
            'closest world',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (showVerbs) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final v in verbsByIds(match.picks.toList()))
                Chip(
                  label: Text('${v.emoji} ${v.label}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Soft gold accent — the brief's signature. Tuned per brightness so it
  /// stays legible on both themes.
  static Color _gold(ThemeData theme) => theme.brightness == Brightness.dark
      ? const Color(0xFFE6C079)
      : const Color(0xFF9A7B2E);
}
