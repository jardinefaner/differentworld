import 'dart:async';
import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/photos/gallery_providers.dart';
import 'package:differentworld/features/photos/person_photo_url.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/subject_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// `/photos` — the program-wide gallery: every room's photos in one
/// day-grouped grid, already labeled (name chip per tile) with the full
/// metadata one tap away. Staff-only; vehicles hidden unless the Source
/// filter asks for them (they're paperwork, not memories).
///
/// The grid stays calm (one chip, hearts only on keepers); tap opens the
/// shared full-screen viewer with a composite caption; long-press opens
/// the metadata sheet (kid, room, time, activity, source, who shot it,
/// who added it).
class PhotosGalleryScreen extends ConsumerStatefulWidget {
  const PhotosGalleryScreen({super.key});

  @override
  ConsumerState<PhotosGalleryScreen> createState() =>
      _PhotosGalleryScreenState();
}

class _PhotosGalleryScreenState extends ConsumerState<PhotosGalleryScreen> {
  GallerySource _source = GallerySource.moments;
  String? _groupId;
  String? _subjectId;

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    if (viewer is GuardianViewer || !viewer.isSignedIn) {
      return const EdgeScaffold(
        body: NoAccess(title: 'Photos live on the staff side.'),
      );
    }
    final labels = ref.watch(verticalLabelsProvider);
    final photosAsync = ref.watch(spacePhotosProvider);
    // A child whose family declined never reaches this wall — see
    // photo_consent.dart. The program's declared default only decides the
    // children nobody has answered for yet.
    final spaceDefaultAllowsPhotos =
        ref
            .watch(viewerProvider)
            .space
            ?.caps
            .getBool(
              SpaceCaps.photoDefaultConsent,
              fallback: true,
            ) ??
        true;
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final subjectsById = {for (final s in subjects) s.id: s};

    return EdgeScaffold(
      body: photosAsync.when(
        loading: () => const LoadingSlot(variant: LoadingVariant.cards),
        error: (_, _) => ErrorState(
          title: 'Could not load photos',
          onRetry: () => ref.invalidate(spacePhotosProvider),
        ),
        data: (all) {
          final filtered = filterGalleryPhotos(
            all,
            source: _source,
            subjectsById: subjectsById,
            groupId: _groupId,
            subjectId: _subjectId,
            spaceDefaultAllowsPhotos: spaceDefaultAllowsPhotos,
          );
          final days = groupGalleryByDay(filtered);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Photos',
                    subtitle: 'Every ${labels.group.toLowerCase()}, one wall.',
                    bottomGap: 8,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _filterChips(groups, subjectsById)),
              if (days.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: 'No photos here yet',
                    message:
                        _source == GallerySource.moments &&
                            _groupId == null &&
                            _subjectId == null
                        ? 'Photos from observations, work samples, and '
                              'photo turns all land on this wall.'
                        : 'Nothing matches this filter — try widening it.',
                  ),
                )
              else
                for (final day in days) ...[
                  SliverToBoxAdapter(child: _dayHeader(day.day)),
                  // Edge-to-edge quilt: compact tiles, hairline gaps, no
                  // side gutters — sizes vary (1×1 / 2×2) deterministically
                  // per photo so the wall never reshuffles. StaggeredGrid
                  // builds a whole day at once; days are bounded and the
                  // feed is capped at 500, so laziness stays at the
                  // sliver-per-day level.
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cols = (constraints.maxWidth / 110).floor().clamp(
                          3,
                          8,
                        );
                        return StaggeredGrid.count(
                          crossAxisCount: cols,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          children: [
                            for (var i = 0; i < day.photos.length; i++)
                              StaggeredGridTile.count(
                                crossAxisCellCount: galleryTileSpan(
                                  day.photos[i].id,
                                ),
                                mainAxisCellCount: galleryTileSpan(
                                  day.photos[i].id,
                                ),
                                child: _GalleryTile(
                                  attachment: day.photos[i],
                                  subjectsById: subjectsById,
                                  onTap: () => _openViewer(
                                    day.photos,
                                    i,
                                    subjectsById,
                                  ),
                                  onLongPress: () => _showMetadata(
                                    day.photos[i],
                                    subjectsById,
                                    groups,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _dayHeader(DateTime day) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final label = dateKey(day) == dateKey(today)
        ? 'Today'
        : dateKey(day) == dateKey(today.subtract(const Duration(days: 1)))
        ? 'Yesterday'
        : DateFormat.MMMEd().format(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _filterChips(List<Group> groups, Map<String, Subject> subjectsById) {
    final pickedSubject = _subjectId == null ? null : subjectsById[_subjectId];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: const Text('All rooms'),
            selected: _groupId == null,
            onSelected: (_) => setState(() => _groupId = null),
          ),
          for (final g in groups) ...[
            const SizedBox(width: 6),
            ChoiceChip(
              label: Text(g.name),
              selected: _groupId == g.id,
              onSelected: (_) => setState(
                () => _groupId = _groupId == g.id ? null : g.id,
              ),
            ),
          ],
          const SizedBox(width: 6),
          FilterChip(
            avatar: pickedSubject == null
                ? const Icon(Icons.person_outline, size: 16)
                : null,
            label: Text(pickedSubject?.firstName ?? 'Kid'),
            selected: _subjectId != null,
            onSelected: (_) => unawaited(_pickSubject()),
          ),
          const SizedBox(width: 6),
          FilterChip(
            avatar: const Icon(Icons.filter_alt_outlined, size: 16),
            label: Text(switch (_source) {
              GallerySource.moments => 'All moments',
              GallerySource.observations => 'Observations',
              GallerySource.turns => 'Photo turns',
              GallerySource.vehicles => 'Vehicles',
            }),
            selected: _source != GallerySource.moments,
            onSelected: (_) => unawaited(_pickSource()),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Future<void> _pickSubject() async {
    if (_subjectId != null) {
      setState(() => _subjectId = null);
      return;
    }
    final picked = await pickSubject(context);
    if (!mounted || picked == null) return;
    setState(() => _subjectId = picked.id);
  }

  Future<void> _pickSource() async {
    final picked = await showGlassSheet<GallerySource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GlassDragHandle(),
            for (final s in GallerySource.values)
              ListTile(
                leading: Icon(switch (s) {
                  GallerySource.moments => Icons.auto_awesome_outlined,
                  GallerySource.observations => Icons.edit_note_outlined,
                  GallerySource.turns => Icons.photo_camera_outlined,
                  GallerySource.vehicles => Icons.directions_bus_outlined,
                }),
                title: Text(switch (s) {
                  GallerySource.moments => 'All moments',
                  GallerySource.observations => 'Observations and work',
                  GallerySource.turns => 'Photo turns (kids shooting)',
                  GallerySource.vehicles => 'Vehicle inspections',
                }),
                selected: _source == s,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _source = picked);
  }

  void _openViewer(
    List<Attachment> dayPhotos,
    int index,
    Map<String, Subject> subjectsById,
  ) {
    unawaited(
      PhotoViewer.open(
        context,
        urls: [for (final a in dayPhotos) a.url],
        initialIndex: index,
        captions: [
          for (final a in dayPhotos) _compositeCaption(a, subjectsById),
        ],
      ),
    );
  }

  String _compositeCaption(Attachment a, Map<String, Subject> subjectsById) {
    final kid = subjectsById[a.subjectId]?.firstName;
    final when = relativeTimeAgo(galleryPhotoTime(a));
    final caption = a.caption;
    return [
      ?kid,
      when,
      if (caption != null && caption.isNotEmpty) caption,
    ].join(' · ');
  }

  /// Fetch the photo's bytes (signed URL → cache) and open the poster tool.
  Future<void> _printBig(Attachment a) async {
    try {
      final signed = await ref.read(
        signedPersonPhotoUrlProvider(a.url).future,
      );
      if (signed == null || signed.isEmpty || !mounted) return;
      final file = await DefaultCacheManager().getSingleFile(signed);
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      unawaited(context.push('/poster', extra: bytes));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't load the photo")),
      );
    }
  }

  void _showMetadata(
    Attachment a,
    Map<String, Subject> subjectsById,
    List<Group> groups,
  ) {
    final subject = subjectsById[a.subjectId];
    final shooter = subjectsById[a.capturedBySubjectId];
    final groupName = groups
        .where((g) => g.id == subject?.groupId)
        .map((g) => g.name)
        .firstOrNull;
    final members = ref.read(membersInSpaceProvider).value ?? const <Member>[];
    final uploader = members
        .where((m) => m.id == a.uploadedBy)
        .map((m) => m.displayName)
        .firstOrNull;
    final time = galleryPhotoTime(a);
    unawaited(
      showGlassSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GlassDragHandle(),
                  Text(
                    [
                      if (subject == null)
                        'Group moment'
                      else
                        '${subject.firstName} ${subject.lastName}',
                      ?groupName,
                    ].join(' — '),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat.MMMEd().format(time)} '
                    '${DateFormat.jm().format(time)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (a.caption case final c? when c.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('“$c”', style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    [
                      switch (a.entityKind) {
                        'entry' => 'From an observation',
                        'vehicle_log' => 'From a vehicle inspection',
                        _ => 'From the camera',
                      },
                      if (shooter != null) 'shot by ${shooter.firstName}',
                      if (uploader != null) 'added by $uploader',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        unawaited(_printBig(a));
                      },
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print big'),
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
}

/// One grid cell: the thumb, a name chip, a keeper heart.
class _GalleryTile extends ConsumerWidget {
  const _GalleryTile({
    required this.attachment,
    required this.subjectsById,
    required this.onTap,
    required this.onLongPress,
  });

  final Attachment attachment;
  final Map<String, Subject> subjectsById;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kid =
        subjectsById[attachment.subjectId] ??
        subjectsById[attachment.capturedBySubjectId];
    final favorited = attachment.sortOrder == 0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Semantics(
        button: true,
        label: kid == null
            ? 'Photo'
            : 'Photo of ${kid.firstName}, opens full screen',
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              PersonPhotoNetwork(
                urlOrPath: attachment.thumbUrl ?? attachment.url,
              ),
              if (kid != null)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      kid.firstName,
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (favorited)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Icon(
                    Icons.favorite,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
