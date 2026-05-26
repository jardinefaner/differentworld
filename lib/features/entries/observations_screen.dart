import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Per-classroom observations feed — narrative + photo entries
/// recorded across the day, newest first. Tap an entry to edit.
/// FAB to add. Gated on `canObserve`.
class ObservationsScreen extends ConsumerWidget {
  const ObservationsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final groupAsync = ref.watch(_groupForObsProvider(groupId));
    final entriesAsync = ref.watch(
      entriesForGroupProvider(
        (groupId: groupId, kind: EntryKind.observation),
      ),
    );

    if (!viewer.canObserve && !viewer.canManageSpace) {
      return const EdgeScaffold(body: NoAccess());
    }

    final group = groupAsync.value;
    return EdgeScaffold(
      actions: [
        // Primary verb in chrome instead of a FAB.extended (which
        // overlapped the omnibox bar on phone + stranded itself on
        // desktop). Wave 94.
        if (viewer.canObserve)
          PrimaryActionButton(
            tooltip: 'New observation',
            icon: Icons.add,
            onPressed: () =>
                context.push('/observations/new?groupId=$groupId'),
          ),
        const SyncStatusIndicator(),
      ],
      body: entriesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load observations',
          onRetry: () => ref.invalidate(
            entriesForGroupProvider(
              (groupId: groupId, kind: EntryKind.observation),
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No observations yet',
              message: viewer.canObserve
                  ? 'Add the first one with the button below.'
                  : 'Observations from teachers will appear here.',
              action: viewer.canObserve
                  ? FilledButton.icon(
                      onPressed: () => context.push(
                        '/observations/new?groupId=$groupId',
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add observation'),
                    )
                  : null,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: entries.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Observations',
                    subtitle: group?.name,
                  ),
                );
              }
              return _ObservationRow(
                entry: entries[i - 1],
                groupId: groupId,
              );
            },
          );
        },
      ),
    );
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _groupForObsProvider = StreamProvider.autoDispose.family<Group?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.groupsDao.watchById(id);
  },
);

class _ObservationRow extends ConsumerWidget {
  const _ObservationRow({required this.entry, required this.groupId});

  final Entry entry;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final when = DateTime.tryParse(entry.recordedAt);
    final whenLabel = when == null ? '' : DateFormat.MMMd().add_jm().format(when);
    final subjectId = entry.subjectId;
    final subjectsAsync = ref.watch(subjectsInGroupProvider(groupId));
    Subject? subject;
    if (subjectId != null && subjectsAsync.value != null) {
      for (final s in subjectsAsync.value!) {
        if (s.id == subjectId) {
          subject = s;
          break;
        }
      }
    }
    final fullName = subject == null
        ? 'Unknown student'
        : '${subject.firstName} ${subject.lastName}';

    final attachmentsAsync = ref.watch(
      attachmentsForEntityProvider((kind: 'entry', id: entry.id)),
    );
    final photos = attachmentsAsync.value?.urls ?? const <String>[];
    return ListTile(
      leading: PersonAvatar(
        name: fullName,
        photoUrl: subject?.photoUrl,
      ),
      title: Text(fullName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.body ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            whenLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: photos.isEmpty
          ? null
          : _PhotoThumb(
              photos: photos,
              onTap: () => PhotoViewer.open(context, urls: photos),
            ),
      isThreeLine: true,
      onTap: () => context.push(
        '/observations/${entry.id}/edit',
        extra: entry,
      ),
    );
  }
}

/// Trailing photo thumbnail. Renders the first attached photo; if the
/// entry has more than one photo, a small "+N" pill overlays the
/// bottom-right so the viewer knows there's more to see.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photos, required this.onTap});

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
                child: PersonPhotoNetwork(
                  urlOrPath: photos.first,
                  errorBuilder: (_) =>
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
