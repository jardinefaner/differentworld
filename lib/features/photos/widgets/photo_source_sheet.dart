import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Bottom sheet shown when the user taps a PersonAvatar that has
/// `onTap` wired. Lets them pick from camera, gallery, or clear the
/// current photo. Handles its own upload + UX (loading spinner,
/// snack-bar success/error).
class PhotoSourceSheet extends ConsumerStatefulWidget {
  const PhotoSourceSheet({
    required this.entity,
    required this.entityId,
    required this.hasExisting,
    required this.displayName,
    super.key,
  });

  final PhotoEntity entity;
  final String entityId;
  final bool hasExisting;
  final String displayName;

  static Future<void> show(
    BuildContext context, {
    required PhotoEntity entity,
    required String entityId,
    required bool hasExisting,
    required String displayName,
  }) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PhotoSourceSheet(
        entity: entity,
        entityId: entityId,
        hasExisting: hasExisting,
        displayName: displayName,
      ),
    );
  }

  @override
  ConsumerState<PhotoSourceSheet> createState() => _PhotoSourceSheetState();
}

class _PhotoSourceSheetState extends ConsumerState<PhotoSourceSheet> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    final service = ref.read(photoServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Phase 1: invoke the picker. The system camera/picker UI takes
    // over; don't show our spinner yet — would be redundant.
    XFile? picked;
    try {
      picked = await service.pickPhoto(source);
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'photos'),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the picker.')),
      );
      return;
    }
    if (picked == null || !mounted) return; // cancelled / unmounted

    // Phase 2: compress + upload. Show the spinner immediately so the
    // sheet doesn't look frozen.
    setState(() => _busy = true);
    try {
      await service.uploadAndPersist(
        entity: widget.entity,
        entityId: widget.entityId,
        picked: picked,
      );
      if (!mounted) {
        // Sheet was dismissed mid-upload. The DB write still landed;
        // surface the success via the host scaffold (best-effort).
        messenger.showSnackBar(
          const SnackBar(content: Text('Photo updated.')),
        );
        return;
      }
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Photo updated.')),
      );
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'photos'),
      );
      // Report the failure even if the sheet has been dismissed —
      // messenger is the root scaffold's, which outlives us.
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not upload that photo.')),
      );
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(photoServiceProvider).clear(
            entity: widget.entity,
            entityId: widget.entityId,
          );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Photo removed.')),
      );
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'photos'),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not remove photo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Photo for ${widget.displayName}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Show "Take a photo" only on native mobile — the one place
          // with a usable in-app camera. On web the camera path needs
          // flaky getUserMedia, and on desktop image_picker has no
          // camera at all (tapping it just errored). Web + desktop get
          // the file-picker path instead (docs/PLATFORM_RUBRIC.md, P1).
          if (isMobileCapturePlatform)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              enabled: !_busy,
              onTap: () => _pick(ImageSource.camera),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            // Copy varies by platform — "library" reads as mobile, "file"
            // reads as web/desktop. The handler routes through
            // ImageSource.gallery either way (a file picker off-mobile).
            title: Text(
              isMobileCapturePlatform ? 'Choose from library' : 'Choose a file…',
            ),
            enabled: !_busy,
            onTap: () => _pick(ImageSource.gallery),
          ),
          if (widget.hasExisting)
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Remove current photo',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              enabled: !_busy,
              onTap: _remove,
            ),
        ],
      ),
    );
  }
}
