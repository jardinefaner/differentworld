import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ObservationSubjectPick extends StatelessWidget {
  const ObservationSubjectPick({
    required this.subject,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Subject subject;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48),
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(48),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonAvatar(
              name: '${subject.firstName} ${subject.lastName}',
              photoUrl: subject.photoUrl,
              radius: 22,
            ),
            const SizedBox(height: 4),
            Text(
              subject.firstName,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class ObservationSelectedSubjectChip extends ConsumerWidget {
  const ObservationSelectedSubjectChip({required this.subjectId, super.key});

  final String? subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subjectId == null) return const SizedBox.shrink();
    // No single-subject provider; one-shot read via DB.
    return FutureBuilder<Subject?>(
      future: () async {
        final db = await ref.read(appDatabaseProvider.future);
        return (db.select(
          db.subjects,
        )..where((s) => s.id.equals(subjectId!))).getSingleOrNull();
      }(),
      builder: (context, snap) {
        final theme = Theme.of(context);
        final s = snap.data;
        if (s == null) return const SizedBox.shrink();
        final name = '${s.firstName} ${s.lastName}';
        return Row(
          children: [
            PersonAvatar(name: name, photoUrl: s.photoUrl),
            const SizedBox(width: 8),
            Text(name, style: theme.textTheme.titleMedium),
          ],
        );
      },
    );
  }
}

/// Multi-photo grid for the observation form. Horizontal scroll of
/// 72-dp thumbs followed by a "+" tile. Each thumb has an X in the
/// corner; tap the thumb itself to open the fullscreen photo viewer
/// for pinch-zoom. Upload state shows as a 72-dp shimmer tile
/// inline.
class ObservationPhotosGrid extends StatelessWidget {
  const ObservationPhotosGrid({
    required this.photos,
    required this.uploading,
    required this.onAdd,
    required this.onView,
    required this.onRemove,
    super.key,
  });

  final List<String> photos;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onView;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Photos',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < photos.length; i++) ...[
                _PhotoTile(
                  url: photos[i],
                  onTap: () => onView(i),
                  onRemove: () => onRemove(i),
                ),
                const SizedBox(width: 8),
              ],
              if (uploading) ...[
                _UploadingTile(),
                const SizedBox(width: 8),
              ],
              _AddTile(onTap: uploading ? null : onAdd),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.url,
    required this.onTap,
    required this.onRemove,
  });

  final String url;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PersonPhotoNetwork(
                  urlOrPath: url,
                  placeholderBuilder: (_) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  errorBuilder: (_) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 20),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: theme.colorScheme.errorContainer,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadingTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              'Add',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
