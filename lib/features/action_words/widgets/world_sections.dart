import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:flutter/material.dart';

/// Accent-tinted section label used across the world screens
/// (this-week hub, the Different Worlds sheet).
class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.text, required this.accent, super.key});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: accent, letterSpacing: 0.4),
      ),
    );
  }
}

/// This week's featured verbs as compact chips, under a label.
class WorldVerbsSection extends StatelessWidget {
  const WorldVerbsSection({
    required this.world,
    required this.accent,
    super.key,
  });
  final CurriculumWorld world;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(text: 'This week’s verbs', accent: accent),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in world.featuredVerbs)
              if (verbById(id) case final v?)
                EntityChipTap(
                  entity: EntityRef(
                    kind: EntityKind.verb,
                    id: v.id,
                    label: v.label,
                  ),
                  child: Chip(
                    label: Text('${v.emoji} ${v.label}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

/// The world's Watch → Do videos + the screen-time guidance line.
class WorldWatchDoSection extends StatelessWidget {
  const WorldWatchDoSection({
    required this.world,
    required this.accent,
    super.key,
  });
  final CurriculumWorld world;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(text: 'Watch → Do', accent: accent),
        for (final v in world.videos)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.play_circle_outline, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${v.title}  ·  ${v.minutes} min',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '→ ${v.after}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          kScreenTimeRules.first,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
