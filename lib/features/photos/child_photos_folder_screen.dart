import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The per-child PROGRESS FOLDER — a browsable collection of one child's
/// photos: the ones they SHOT (their own camera turns) and the ones OF them
/// (where they appear). The payoff of the per-child media tagging (the
/// `captured_by_subject_id` / `subject_id` axes on `attachments`).
///
/// Two lenses via a segmented toggle:
/// - **Took** — `attachmentsCapturedByCuratedProvider`, FAVORITES-FIRST. A
///   hearted shot floats to the top (the heart writes `sort_order = 0`, the
///   same favorite mechanism the photo-turns review uses).
/// - **Of {name}** — `attachmentsForSubjectProvider`, newest-first.
///
/// STAFF-side surface (the child's own folder on the subject detail). The
/// other-child-name scrub does NOT apply here — that's a family/export rule
/// (CLAUDE.md). The heart (a curation write) is gated on `canObserve`, so a
/// guardian reaching this folder gets a calm read-only gallery.
class ChildPhotosFolderScreen extends ConsumerStatefulWidget {
  const ChildPhotosFolderScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  ConsumerState<ChildPhotosFolderScreen> createState() =>
      _ChildPhotosFolderScreenState();
}

enum _Lens { took, of }

class _ChildPhotosFolderScreenState
    extends ConsumerState<ChildPhotosFolderScreen> {
  _Lens _lens = _Lens.took;

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);

    // Guardians can only see THEIR kids — mirror the subject-detail gate.
    if (viewer is GuardianViewer && !viewer.canSeeSubject(widget.subjectId)) {
      return const EdgeScaffold(
        body: NoAccess(title: "That isn't one of your children."),
      );
    }

    final subject = ref.watch(subjectByIdProvider(widget.subjectId)).value;
    final firstName = (subject?.firstName ?? '').trim();
    final possessive = firstName.isEmpty ? 'This child' : firstName;

    final tookAsync = ref.watch(
      attachmentsCapturedByCuratedProvider(widget.subjectId),
    );
    final ofAsync = ref.watch(
      attachmentsForSubjectProvider(widget.subjectId),
    );

    final active = _lens == _Lens.took ? tookAsync : ofAsync;
    // Heart-to-favorite is a curation write — staff only. Only the "Took"
    // lens carries the favorite ordering, so the heart shows there.
    final canFavorite = viewer.canObserve && _lens == _Lens.took;

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: active.when(
        loading: () => const LoadingSlot(variant: LoadingVariant.cards),
        error: (_, _) => ErrorState(
          title: 'Could not load photos',
          onRetry: () {
            ref
              ..invalidate(
                attachmentsCapturedByCuratedProvider(widget.subjectId),
              )
              ..invalidate(attachmentsForSubjectProvider(widget.subjectId));
          },
        ),
        data: (photos) {
          // The favorite count is read from the curated (Took) list — it's
          // the only lens where the heart applies.
          final tookPhotos = tookAsync.value ?? const <Attachment>[];
          final favorites = tookPhotos
              .where((p) => (p.sortOrder ?? 1) == 0)
              .length;
          final subtitle = _subtitle(
            tookCount: tookPhotos.length,
            ofCount: (ofAsync.value ?? const <Attachment>[]).length,
            favorites: favorites,
          );

          // Cap + center on wide windows so the grid doesn't run edge-to-edge
          // on a desktop monitor (matches the subject-detail treatment).
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.splitMaxWidth,
              ),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: ContentHeader(
                        title: firstName.isEmpty
                            ? 'Photos'
                            : "$firstName's photos",
                        subtitle: subtitle,
                        bottomGap: 12,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _LensToggle(
                        lens: _lens,
                        ofLabel: 'Of $possessive',
                        onChanged: (l) => setState(() => _lens = l),
                      ),
                    ),
                  ),
                  if (photos.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyForLens(lens: _lens, name: possessive),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: _PhotoGrid(
                        photos: photos,
                        canFavorite: canFavorite,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _subtitle({
    required int tookCount,
    required int ofCount,
    required int favorites,
  }) {
    final total = tookCount + ofCount;
    if (total == 0) return 'No photos yet';
    final photoWord = total == 1 ? 'photo' : 'photos';
    final favPart = favorites == 0
        ? ''
        : ' · $favorites ${favorites == 1 ? 'favorite' : 'favorites'}';
    return '$total $photoWord$favPart';
  }
}

/// The "Took" / "Of {name}" segmented control. Icon + label per segment (never
/// color alone), so the active lens reads without relying on the fill.
class _LensToggle extends StatelessWidget {
  const _LensToggle({
    required this.lens,
    required this.ofLabel,
    required this.onChanged,
  });

  final _Lens lens;
  final String ofLabel;
  final ValueChanged<_Lens> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_Lens>(
      segments: [
        const ButtonSegment(
          value: _Lens.took,
          icon: Icon(Icons.photo_camera_outlined, size: 18),
          label: Text('Took'),
        ),
        ButtonSegment(
          value: _Lens.of,
          icon: const Icon(Icons.face_outlined, size: 18),
          label: Text(ofLabel),
        ),
      ],
      selected: {lens},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Empty-state copy per lens — a child shoots vs appears, two different
/// stories, so the nudge differs.
class _EmptyForLens extends StatelessWidget {
  const _EmptyForLens({required this.lens, required this.name});

  final _Lens lens;
  final String name;

  @override
  Widget build(BuildContext context) {
    final message = lens == _Lens.took
        ? 'Photos $name takes on their camera turns will collect here.'
        : 'Photos of $name from activities and photo turns will collect here.';
    return EmptyState(
      icon: Icons.photo_library_outlined,
      title: 'No photos yet',
      message: message,
      // The folder fills from activities — point at today's run so an empty
      // folder isn't a dead end.
      action: TextButton(
        onPressed: () => context.go('/today'),
        child: const Text('Go to today'),
      ),
    );
  }
}

/// Responsive photo grid. Square tiles, ~120dp wide → more columns on a
/// tablet/desktop, two on a phone. Tap any photo to open the full-screen
/// viewer at that index.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.canFavorite});

  final List<Attachment> photos;
  final bool canFavorite;

  @override
  Widget build(BuildContext context) {
    final urls = photos.map((p) => p.url).toList(growable: false);
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 168,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) => _PhotoCell(
          photo: photos[i],
          allUrls: urls,
          index: i,
          canFavorite: canFavorite,
        ),
        childCount: photos.length,
      ),
    );
  }
}

/// One photo in the grid. Tap → full-screen viewer. Heart (staff, "Took"
/// lens) → favorite / un-favorite, mirroring the photo-turns review.
///
/// Stateful for the same single reason as the review's `_ReviewPhoto`: a
/// `_pending` guard. The favorited state derives from the live `sort_order`,
/// so a fast double-tap could land two writes (`0` then the sentinel) in an
/// unpredictable order. `_pending` drops the second tap until the first
/// write returns.
class _PhotoCell extends ConsumerStatefulWidget {
  const _PhotoCell({
    required this.photo,
    required this.allUrls,
    required this.index,
    required this.canFavorite,
  });

  final Attachment photo;
  final List<String> allUrls;
  final int index;
  final bool canFavorite;

  @override
  ConsumerState<_PhotoCell> createState() => _PhotoCellState();
}

class _PhotoCellState extends ConsumerState<_PhotoCell> {
  /// Sentinel for "not a favorite" — large so favorites (0) always sort
  /// above it. Same value the photo-turns review uses.
  static const int _notFavorite = 1000000000;

  bool _pending = false;

  bool get _favorited => (widget.photo.sortOrder ?? 1) == 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fav = _favorited;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: true,
              label: 'Open photo',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openViewer,
                child: PersonPhotoNetwork(
                  urlOrPath: widget.photo.thumbUrl ?? widget.photo.url,
                  placeholderBuilder: (_) => ColoredBox(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
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
          // Favorited ring — a visible cue beyond the heart fill.
          if (widget.canFavorite && fav)
            Positioned.fill(
              // Keyed: this child is conditional, so its appearance shifts the
              // sibling indices — without keys Flutter would mis-match the
              // heart-button Element by position (the Stack-keys gotcha).
              key: const ValueKey('fav-ring'),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.canFavorite)
            Positioned(
              key: const ValueKey('fav-btn'),
              right: 4,
              bottom: 4,
              child: _FavoriteButton(
                favorited: fav,
                onTap: () => unawaited(_toggleFavorite()),
              ),
            ),
        ],
      ),
    );
  }

  void _openViewer() {
    unawaited(
      PhotoViewer.open(
        context,
        urls: widget.allUrls,
        initialIndex: widget.index,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_pending) return;
    setState(() => _pending = true);
    final next = _favorited ? _notFavorite : 0;
    try {
      await ref
          .read(attachmentActionsProvider)
          .reorder(id: widget.photo.id, sortOrder: next);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}

/// The heart toggle. Icon + fill (never color alone), 48dp tap target via a
/// SizedBox around a ~36dp visual. Matches the photo-turns review's heart.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.favorited, required this.onTap});

  final bool favorited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: favorited ? 'Remove favorite' : 'Mark favorite',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 48dp tap target (a11y min) around a ~36dp visual heart.
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0x80000000), // raw-canvas: scrim over a photo
                shape: BoxShape.circle,
              ),
              child: Icon(
                favorited ? Icons.favorite : Icons.favorite_border,
                color: favorited
                    ? Colors
                          .pinkAccent // raw-canvas: over a photo
                    : Colors.white, // raw-canvas: over a photo
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
