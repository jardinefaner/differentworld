import 'dart:async';

import 'package:differentworld/features/game_content/custom_pictures.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// `/games/pictures` — the staff-authored picture library for "Reveal the
/// Picture" (docs/CONTENT_BANK.md, Wave 1b). Upload / name / remove your own
/// pictures; the grid game plays them. Rides `content_items` — no new table.
class PictureLibraryScreen extends ConsumerStatefulWidget {
  const PictureLibraryScreen({super.key});

  @override
  ConsumerState<PictureLibraryScreen> createState() =>
      _PictureLibraryScreenState();
}

class _PictureLibraryScreenState extends ConsumerState<PictureLibraryScreen> {
  bool _adding = false;

  Future<void> _add() async {
    if (_adding) return;
    // Capture the messenger BEFORE any await so feedback survives context churn.
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      // 1. Camera or gallery.
      final source = await _pickSource();
      if (source == null || !mounted) return;
      // 2. Pick the image. image_picker can THROW (permission / camera
      // PlatformException) — that used to escape unhandled and the whole flow
      // died silently ("nothing after I pick"). Now it surfaces.
      final picked = await ref.read(photoServiceProvider).pickPhoto(source);
      if (kDebugMode) {
        debugPrint('[pics] source=$source picked=${picked?.path} mounted=$mounted');
      }
      if (picked == null) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('No photo selected.')),
        );
        return;
      }
      if (!mounted) return;
      // 3. Upload + create (offline → queued). Add now; name it on the tile
      // (matches the mock — the tile shows "Add a name…").
      setState(() => _adding = true);
      await ref
          .read(customPictureActionsProvider)
          .add(picked: picked, label: '');
    } on Object catch (e, st) {
      if (kDebugMode) debugPrint('[pics] add failed: $e\n$st');
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not add the picture: $e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<ImageSource?> _pickSource() {
    return showGlassSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptLabel({String initial = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('What is it?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Lion · Our playground'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(CustomPicture pic) async {
    final label = await _promptLabel(initial: pic.label);
    if (label == null || label.isEmpty || !mounted) return;
    await ref.read(customPictureActionsProvider).rename(pic, label);
  }

  Future<void> _remove(CustomPicture pic) async {
    final actions = ref.read(customPictureActionsProvider);
    await deleteWithUndo(
      context,
      label: pic.label.isEmpty ? 'picture' : pic.label,
      onDelete: () => actions.delete(pic.id),
      onUndo: () => actions.restore(pic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picsAsync = ref.watch(customPicturesProvider);
    return EdgeScaffold(
      backFallbackRoute: '/today',
      actions: [
        IconButton(
          tooltip: 'Add pictures',
          onPressed: _adding ? null : _add,
          icon: const Icon(Icons.add_a_photo_outlined),
        ),
      ],
      body: picsAsync.when(
        loading: () => const LoadingSlot(variant: LoadingVariant.cards),
        error: (e, _) => ErrorState(
          title: "Couldn't load your pictures",
          detail: '$e',
          onRetry: () => ref.invalidate(customPicturesProvider),
        ),
        data: (pics) => _Body(
          pics: pics,
          adding: _adding,
          onAdd: _add,
          onRename: _rename,
          onRemove: _remove,
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.pics,
    required this.adding,
    required this.onAdd,
    required this.onRename,
    required this.onRemove,
  });

  final List<CustomPicture> pics;
  final bool adding;
  final VoidCallback onAdd;
  final ValueChanged<CustomPicture> onRename;
  final ValueChanged<CustomPicture> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (pics.isEmpty && !adding) {
      // Plain box layout (not slivers): EmptyState uses a LayoutBuilder, which
      // SliverFillRemaining can't intrinsic-measure. Header + Expanded is enough
      // — the empty state has nothing to scroll.
      return Column(
        children: [
          const _Header(),
          Expanded(
            child: EmptyState(
              icon: Icons.add_a_photo_outlined,
              title: 'No pictures yet',
              message:
                  'Add your own photos — your class dog, the playground, a '
                  'favorite book — and they play in Reveal the Picture.',
              action: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add pictures'),
              ),
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _Header()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i == pics.length) {
                  return _AddTile(onTap: onAdd, busy: adding);
                }
                final pic = pics[i];
                return _PictureTile(
                  pic: pic,
                  onRename: () => onRename(pic),
                  onRemove: () => onRemove(pic),
                );
              },
              childCount: pics.length + 1,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _MixToggle(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Text(
              'Shared with your whole team · saved offline, uploads when online.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => const ContentHeader(
        title: 'Your pictures',
        subtitle:
            'These play in Reveal the Picture — kids guess as the grid lifts. '
            'Tap one to rename or remove.',
      );
}

class _PictureTile extends StatelessWidget {
  const _PictureTile({
    required this.pic,
    required this.onRename,
    required this.onRemove,
  });

  final CustomPicture pic;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onRename,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (pic.isPending)
                    ColoredBox(
                      color: scheme.surfaceContainerHigh,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    PersonPhotoNetwork(
                      urlOrPath: pic.path,
                      placeholderBuilder: (_) => ColoredBox(
                        color: scheme.surfaceContainerHigh,
                      ),
                    ),
                  if (pic.isPending)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: _Chip(label: 'uploading…', scheme: scheme),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      pic.label.isEmpty ? 'Add a name…' : pic.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: pic.label.isEmpty
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  _TileMenu(onRename: onRename, onRemove: onRemove),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.scheme});
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onTertiaryContainer,
        ),
      ),
    );
  }
}

class _TileMenu extends StatelessWidget {
  const _TileMenu({required this.onRename, required this.onRemove});
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, color: Theme.of(context).colorScheme.onSurfaceVariant),
      tooltip: 'Picture options',
      onSelected: (v) => v == 'rename' ? onRename() : onRemove(),
      itemBuilder: (_) => const [
        PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
        PopupMenuItem<String>(value: 'remove', child: Text('Remove')),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, required this.busy});
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DottedTile(
      onTap: busy ? null : onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.add_a_photo_outlined, size: 30, color: scheme.onSurfaceVariant),
          const SizedBox(height: 7),
          Text(
            busy ? 'Adding…' : 'Add pictures',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (!busy)
            Text(
              'camera or gallery',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// A dashed-border tappable tile (the "+ Add" affordance).
class DottedTile extends StatelessWidget {
  const DottedTile({required this.child, this.onTap, super.key});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: scheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _MixToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mix = ref.watch(gridMixEmojiProvider).value ?? true;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: SwitchListTile(
        value: mix,
        onChanged: (v) =>
            unawaited(ref.read(gridMixEmojiProvider.notifier).set(value: v)),
        title: const Text('Mix with the built-in emoji'),
        subtitle: Text(
          mix
              ? 'Your pictures play alongside the built-in set.'
              : 'Only your pictures play.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
