import 'package:differentworld/features/heroes/hero_catalog.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The **Hero card** (docs/VISION.md 2026-06-19) — a child's make-believe
/// alter-ego rendered as a keepsake: the animal + skin, the `[Name] of [From]`
/// title, the powers, and the drawing they made + named.
///
/// Reusable: the creator shows it as a live preview, the Heroes hub shows one
/// per child. When [entryId] is given it watches that entry's attachments to
/// show the drawing; pass null (a draft preview) to skip the drawing block.
class HeroCard extends ConsumerWidget {
  const HeroCard({required this.data, this.entryId, super.key});

  final HeroCardData data;

  /// The hero entry's id, so the card can load its drawing attachment. Null for
  /// a live draft preview (no saved row yet → no drawing).
  final String? entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final animalEmoji = data.animal?.emoji ?? '⭐';
    final species = data.speciesLabel;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(left: BorderSide(color: scheme.primary, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  animalEmoji,
                  style: const TextStyle(fontSize: 34),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (species.isNotEmpty)
                      Text(
                        species,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      data.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (data.powers.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final p in data.powers)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      p.emoji.isEmpty ? p.label : '${p.emoji} ${p.label}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (entryId != null)
            _Drawing(entryId: entryId!, name: data.drawingName),
        ],
      ),
    );
  }
}

/// The drawing block — the child's named drawing, loaded from the hero entry's
/// attachments. Renders nothing until/unless a drawing is attached.
class _Drawing extends ConsumerWidget {
  const _Drawing({required this.entryId, required this.name});

  final String entryId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final photos =
        ref
            .watch(attachmentsForEntityProvider((kind: 'entry', id: entryId)))
            .value
            ?.urls ??
        const <String>[];
    if (photos.isEmpty) return const SizedBox.shrink();
    // The most recent attachment is the current drawing (sort_order ascending,
    // so the last one wins).
    final current = photos.last;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => PhotoViewer.open(context, urls: photos),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PersonPhotoNetwork(
                urlOrPath: current,
                width: 56,
                height: 56,
                errorBuilder: (_) => const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'their drawing',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  (name == null || name!.isEmpty) ? 'untitled' : '“$name”',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
