import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/shared/widgets/hover_tap.dart';
import 'package:flutter/material.dart';

/// Compact square thumbnail for an entity's attached photos. Renders the
/// first photo; when there's more than one, a small "+N" pill overlays
/// the bottom-right corner so the viewer knows there's more to see.
///
/// Used by the observation feeds (tappable trailing thumb that opens the
/// photo viewer) and the capture inbox (passive cue, no [onTap] — the
/// row keeps its one-tap-to-triage model). Signed URLs are minted by
/// [PersonPhotoNetwork].
class AttachmentPhotoThumb extends StatelessWidget {
  const AttachmentPhotoThumb({
    required this.photos,
    this.size = 44,
    this.onTap,
    this.badgeOffset = -4,
    this.errorIconSize,
    super.key,
  });

  /// Attachment photo URLs/paths; the first one renders, the rest count
  /// into the "+N" pill.
  final List<String> photos;

  /// Square edge length of the thumb.
  final double size;

  /// When non-null, the thumb is wrapped in a [HoverTap] tap target.
  final VoidCallback? onTap;

  /// How far the "+N" pill hangs past the bottom-right corner.
  final double badgeOffset;

  /// Size of the broken-image fallback icon (null = icon default).
  final double? errorIconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = photos.length - 1;
    final thumb = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: PersonPhotoNetwork(
                urlOrPath: photos.first,
                errorBuilder: (_) => Icon(
                  Icons.broken_image_outlined,
                  size: errorIconSize,
                ),
              ),
            ),
          ),
          if (extras > 0)
            Positioned(
              bottom: badgeOffset,
              right: badgeOffset,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$extras',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return thumb;
    return HoverTap(onTap: onTap, child: thumb);
  }
}
