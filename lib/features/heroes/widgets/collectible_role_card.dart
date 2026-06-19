import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/heroes/hero_catalog.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A child's role (their Hero) rendered as a **collectible card** for the room's
/// deck (docs/VISION.md 2026-06-19 — "the role they play… collectible… card
/// games"). The keepsake-deck model: one card per child, no gacha. The portrait
/// is the child's DRAWING when they made one, else the animal emoji (the
/// app-made version) — so "drawn or app-creates it" is visible on the card.
///
/// Calm-collectible: a full-bordered card with a soft per-animal accent header,
/// not a loud trading-card gradient. The variety reads from the emoji + role +
/// powers, the way the deck stays cohesive.
class CollectibleRoleCard extends ConsumerWidget {
  const CollectibleRoleCard({
    required this.data,
    this.entryId,
    this.childName,
    super.key,
  });

  final HeroCardData data;

  /// The hero entry's id — so the portrait can be the child's drawing. Null →
  /// the emoji portrait (a draft / app-made version).
  final String? entryId;

  /// "{childName}'s card" footer; null hides it.
  final String? childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = roleAccent(data.animal?.id);
    final emoji = data.animal?.emoji ?? '⭐';
    final species = data.speciesLabel;

    final eid = entryId;
    final drawing = eid == null
        ? null
        : ref
              .watch(attachmentsForEntityProvider((kind: 'entry', id: eid)))
              .value
              ?.urls
              .lastOrNull;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The portrait band — the drawing when there is one, else the emoji.
          Container(
            color: accent.withValues(alpha: 0.16),
            height: 116,
            alignment: Alignment.center,
            child: drawing == null
                ? Text(emoji, style: const TextStyle(fontSize: 56))
                : PersonPhotoNetwork(
                    urlOrPath: drawing,
                    width: double.infinity,
                    height: 116,
                    errorBuilder: (_) =>
                        Text(emoji, style: const TextStyle(fontSize: 56)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (species.isNotEmpty)
                  Text(
                    species,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  data.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (data.powers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    data.powers
                        .take(3)
                        .map((p) => p.emoji.isEmpty ? p.label : p.emoji)
                        .join('  '),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                if (childName != null && childName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$childName’s card',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A calm, deterministic accent for a role's animal — so the deck has variety
/// without a loud palette. Stable per animal id (a card keeps its tint).
Color roleAccent(String? animalId) {
  if (animalId == null || animalId.isEmpty) return ActivityPalette.indigo;
  const palette = <Color>[
    ActivityPalette.teal,
    ActivityPalette.amber,
    ActivityPalette.purple,
    ActivityPalette.green,
    ActivityPalette.brown,
    ActivityPalette.blue,
    ActivityPalette.pink,
    ActivityPalette.cyan,
  ];
  var h = 0;
  for (final c in animalId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}
