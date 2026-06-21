import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entities/linkified_text.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/shared/widgets/hover_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SubjectObservationItem extends ConsumerWidget {
  const SubjectObservationItem({required this.entry, super.key});

  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final when = DateTime.tryParse(entry.recordedAt);
    final whenLabel =
        when == null ? '' : DateFormat.MMMd().add_jm().format(when);
    final attachmentsAsync = ref.watch(
      attachmentsForEntityProvider((kind: 'entry', id: entry.id)),
    );
    final photos = attachmentsAsync.value?.urls ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              whenLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            LinkifiedText(entry.body ?? ''),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ObservationPhotosStrip(photos: photos),
            ],
          ],
        ),
      ),
    );
  }
}

class _ObservationPhotosStrip extends StatelessWidget {
  const _ObservationPhotosStrip({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (photos.length == 1) {
      return HoverTap(
        onTap: () => PhotoViewer.open(context, urls: photos),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: PersonPhotoNetwork(
            urlOrPath: photos.first,
            errorBuilder: (_) => Container(
              height: 200,
              color: theme.colorScheme.surfaceContainerHigh,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => HoverTap(
          onTap: () => PhotoViewer.open(
            context,
            urls: photos,
            initialIndex: i,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 160,
              child: PersonPhotoNetwork(
                urlOrPath: photos[i],
                errorBuilder: (_) => Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
