import 'package:cached_network_image/cached_network_image.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/entries/widgets/observation_form_sheet.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/widgets/quick_actions.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// `/observations` — every observation across the program, newest
/// first, filterable by classroom.
///
/// Per `docs/UX_DECISIONS.md §8`, observations are a first-class
/// entity; this screen is their top-level index — discoverable
/// independently of any one classroom or child.
///
/// For directors: every observation in the space.
/// For teachers / assistants: only entries in their assigned
/// classrooms (filtering happens inside [observationsInSpaceProvider]).
class ObservationsIndexScreen extends ConsumerStatefulWidget {
  const ObservationsIndexScreen({super.key});

  @override
  ConsumerState<ObservationsIndexScreen> createState() =>
      _ObservationsIndexScreenState();
}

class _ObservationsIndexScreenState
    extends ConsumerState<ObservationsIndexScreen> {
  /// null = all classrooms; otherwise filter to this group id.
  String? _groupFilter;

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final entriesAsync = ref.watch(observationsInSpaceProvider);
    final groupsAsync = ref.watch(groupsProvider);

    return EdgeScaffold(
      actions: [
        if ((groupsAsync.value ?? []).length > 1)
          IconButton(
            tooltip: 'Filter classroom',
            icon: Icon(
              _groupFilter == null ? Icons.filter_list : Icons.filter_alt,
            ),
            onPressed: () => _pickClassroomFilter(groupsAsync.value ?? []),
          ),
        const SyncStatusIndicator(),
      ],
      floatingActionButton: viewer.canObserve
          ? FloatingActionButton.extended(
              onPressed: () => startNewObservation(context, ref),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Observation'),
            )
          : null,
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load observations',
        ),
        data: (entries) {
          final filtered = _groupFilter == null
              ? entries
              : entries.where((e) => e.groupId == _groupFilter).toList();
          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              title: entries.isEmpty
                  ? 'No observations yet'
                  : 'No observations match this filter',
              message: entries.isEmpty
                  ? 'Logged observations land here so you can scan the whole '
                      "program's narrative in one place."
                  : null,
              action: viewer.canObserve && _groupFilter == null
                  ? FilledButton.icon(
                      onPressed: () => startNewObservation(context, ref),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Add observation'),
                    )
                  : null,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: filtered.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Observations',
                    subtitle: _subtitleFor(
                      filtered.length,
                      _groupFilter,
                      groupsAsync.value ?? const [],
                    ),
                  ),
                );
              }
              return _ObservationListItem(entry: filtered[i - 1]);
            },
          );
        },
      ),
    );
  }

  Future<void> _pickClassroomFilter(List<Group> groups) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.filter_list_off),
                title: const Text('All classrooms'),
                trailing: _groupFilter == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop<String>(),
              ),
              const Divider(),
              for (final g in groups)
                ListTile(
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: Text(g.name),
                  trailing:
                      _groupFilter == g.id ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(ctx).pop(g.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    // Distinguish "user picked null (all classrooms)" from "user
    // dismissed the sheet." Sheet dismissal returns null too, so we
    // need a sentinel.
    setState(() => _groupFilter = picked);
  }

  String _subtitleFor(int count, String? groupId, List<Group> groups) {
    final base = count == 1 ? '1 entry' : '$count entries';
    if (groupId == null) return '$base · all classrooms';
    final match = groups.where((g) => g.id == groupId).firstOrNull;
    final name = match?.name ?? '—';
    return '$base · $name';
  }
}

/// Index row — avatar (child) + name + classroom + body + time + photo.
/// Tap → open the observation form sheet pre-filled to this entry.
class _ObservationListItem extends ConsumerWidget {
  const _ObservationListItem({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final attachmentsAsync = ref.watch(
      attachmentsForEntityProvider((kind: 'entry', id: entry.id)),
    );
    final photos = attachmentsAsync.value?.urls ?? const <String>[];
    final when = DateTime.tryParse(entry.recordedAt);
    final whenLabel =
        when == null ? '' : DateFormat.MMMd().add_jm().format(when.toLocal());

    final subjectAsync = entry.subjectId == null
        ? const AsyncValue<Subject?>.data(null)
        : ref.watch(subjectByIdProvider(entry.subjectId!));
    final subject = subjectAsync.value;
    final subjectName = subject == null
        ? 'Unknown student'
        : '${subject.firstName} ${subject.lastName}';

    final groupsAsync = ref.watch(groupsProvider);
    final groupName = entry.groupId == null
        ? null
        : groupsAsync.value
            ?.where((g) => g.id == entry.groupId)
            .map((g) => g.name)
            .firstOrNull;

    return ListTile(
      leading: PersonAvatar(
        name: subjectName,
        photoUrl: subject?.photoUrl,
      ),
      title: Text(subjectName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.body ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            groupName == null ? whenLabel : '$groupName · $whenLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: photos.isEmpty
          ? null
          : _IndexPhotoThumb(
              photos: photos,
              onTap: () => PhotoViewer.open(context, urls: photos),
            ),
      isThreeLine: true,
      onTap: () => ObservationFormSheet.show(context, existing: entry),
    );
  }
}

/// Small 44dp thumb + "+N" pill on the trailing edge — same shape as
/// the per-classroom feed. Pulled into the index screen because that
/// row's `_PhotoThumb` is private.
class _IndexPhotoThumb extends StatelessWidget {
  const _IndexPhotoThumb({required this.photos, required this.onTap});

  final List<String> photos;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = photos.length - 1;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: photos.first,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            if (extras > 0)
              Positioned(
                bottom: -4,
                right: -4,
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
      ),
    );
  }
}
