import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entities/linkified_text.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/attachment_photo_thumb.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/breakpoints.dart';
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). The narrative rows are TEXT-HEAVY, so the bento
    // variant keeps them FULL-WIDTH on phone (1-up) and only goes 2-up where
    // there's room (tablet/desktop) — a max-extent grid, still LAZY, over the
    // SAME provider. Off keeps the existing single-column feed.
    final bento = bentoEnabled(ref, perScreen: null);

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
            onPressed: () => context.push('/observations/new?groupId=$groupId'),
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
                  ? 'A moment you noticed, in a sentence — it becomes part of '
                        'this child’s story.'
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
          final header = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(
              title: 'Observations',
              subtitle: group?.name,
            ),
          );
          // Cap + center the feed on desktop/web — the rows are ListTiles
          // (their own 16dp padding), so a width cap is the right fix rather
          // than ResponsivePage's extra padding.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.splitMaxWidth,
              ),
              child: bento
                  ? _ObservationsBentoGrid(
                      header: header,
                      entries: entries,
                      groupId: groupId,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: entries.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) return header;
                        return _ObservationRow(
                          entry: entries[i - 1],
                          groupId: groupId,
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// The bento variant of the observations feed — the SAME entries, kept LAZY
/// and re-laid as a max-cross-axis-extent grid. The narrative rows are
/// text-heavy, so a `maxCrossAxisExtent` of 440 keeps them FULL-WIDTH (1-up)
/// on a phone (which never reaches 440 inside the width cap) and only goes
/// 2-up on tablet/desktop where the body has room — never truncating the
/// 3-line narrative more than the flat feed already does. Cells are
/// fixed-height (the row's body is bounded — avatar + 3-line ellipsised body
/// + timestamp), and the height scales with the text-size setting so a large
/// scale doesn't overflow the cell (the fixed-aspect-ratio trap).
class _ObservationsBentoGrid extends StatelessWidget {
  const _ObservationsBentoGrid({
    required this.header,
    required this.entries,
    required this.groupId,
  });

  final Widget header;
  final List<Entry> entries;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    // Title-relative text scale (1.0 = OS default) so the fixed cell height
    // grows with the user's text-size setting instead of clipping.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 440,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 96 + 32 * textScale,
            ),
            itemCount: entries.length,
            itemBuilder: (_, i) => _ObservationRow(
              entry: entries[i],
              groupId: groupId,
              inGrid: true,
            ),
          ),
        ),
      ],
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
  const _ObservationRow({
    required this.entry,
    required this.groupId,
    this.inGrid = false,
  });

  final Entry entry;
  final String groupId;

  /// When laid out as a fixed-height bento grid cell, drop the outer
  /// padding (grid spacing handles the gaps) so the card fills the cell.
  final bool inGrid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final when = DateTime.tryParse(entry.recordedAt);
    final whenLabel = when == null
        ? ''
        : DateFormat.MMMd().add_jm().format(when);
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
    // Calm card: a narrative observation reads warmer on a tile than as a flat
    // row. Vertical list (recency preserved) — just on-brand cards.
    final card = Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        leading: PersonAvatar(
          name: fullName,
          photoUrl: subject?.photoUrl,
        ),
        title: Text(fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinkifiedText(
              entry.body ?? '',
              // Two lines in the fixed-height grid cell so a long narrative
              // can't overflow it; three in the flexible flat list.
              maxLines: inGrid ? 2 : 3,
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
            : AttachmentPhotoThumb(
                photos: photos,
                onTap: () => PhotoViewer.open(context, urls: photos),
              ),
        isThreeLine: true,
        onTap: () => context.push(
          '/observations/${entry.id}/edit',
          extra: entry,
        ),
      ),
    );
    // In a fixed-height grid cell, fill the cell (no outer padding — grid
    // spacing handles the gaps). In the flat list, keep the row's own
    // horizontal margin + bottom gap.
    if (inGrid) return SizedBox.expand(child: card);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: card,
    );
  }
}
