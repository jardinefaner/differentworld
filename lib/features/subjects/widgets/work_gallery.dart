import 'dart:async';
import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/shared/widgets/hover_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A child's cumulative WORK — the photos snapped of their paper (docs/
/// VISION.md "writing their answers on paper, cumulative"). A horizontal
/// strip of thumbnails; tap to view full, tap the star to mark a keeper for
/// the Summer Book (the "curate" half of snap-and-curate).
class WorkGallery extends ConsumerWidget {
  const WorkGallery({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final samples =
        ref
            .watch(
              entriesForSubjectProvider(
                (subjectId: subjectId, kind: EntryKind.workSample),
              ),
            )
            .value ??
        const <Entry>[];
    if (samples.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'No work yet — tap “Snap work” above to photograph their paper.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: samples.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _WorkTile(entry: samples[i]),
      ),
    );
  }
}

class _WorkTile extends ConsumerWidget {
  const _WorkTile({required this.entry});

  final Entry entry;

  bool get _inBook {
    try {
      final d = entry.details.trim().isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(entry.details) as Map<String, dynamic>;
      return d['in_book'] == true;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final photos =
        ref
            .watch(attachmentsForEntityProvider((kind: 'entry', id: entry.id)))
            .value
            ?.urls ??
        const <String>[];
    final inBook = _inBook;
    return SizedBox(
      width: 120,
      child: Stack(
        children: [
          Positioned.fill(
            child: HoverTap(
              onTap: photos.isEmpty
                  ? null
                  : () => PhotoViewer.open(context, urls: photos),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: photos.isEmpty
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: const Center(
                          child: Icon(Icons.image_outlined),
                        ),
                      )
                    : PersonPhotoNetwork(
                        urlOrPath: photos.first,
                        errorBuilder: (_) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          // Curate: star a keeper for the Summer Book.
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: inBook ? 'In the book' : 'Add to the book',
                iconSize: 18,
                color: Colors.white,
                icon: Icon(inBook ? Icons.star : Icons.star_border),
                onPressed: () => unawaited(
                  ref
                      .read(entryActionsProvider)
                      .setWorkSampleInBook(entry, inBook: !inBook),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
