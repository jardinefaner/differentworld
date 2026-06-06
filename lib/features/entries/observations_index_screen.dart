import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/widgets/quick_actions.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        if (viewer.canObserve)
          PrimaryActionButton(
            tooltip: 'New observation',
            icon: Icons.edit_note_outlined,
            onPressed: () => startNewObservation(context, ref),
          ),
        const SyncStatusIndicator(),
      ],
      body: entriesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load observations',
          onRetry: () => ref.invalidate(observationsInSpaceProvider),
        ),
        data: (entries) {
          final groups = groupsAsync.value ?? const <Group>[];
          final filtered = _groupFilter == null
              ? entries
              : entries.where((e) => e.groupId == _groupFilter).toList();
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No observations yet',
              message:
                  'Logged observations land here so you can scan the whole '
                  "program's narrative in one place.",
              action: viewer.canObserve
                  ? FilledButton.icon(
                      onPressed: () => startNewObservation(context, ref),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Add observation'),
                    )
                  : null,
            );
          }
          return _ObservationsFeed(
            entries: filtered,
            allCount: entries.length,
            groups: groups,
            groupFilter: _groupFilter,
            onFilterChanged: (g) => setState(() => _groupFilter = g),
          );
        },
      ),
    );
  }
}

class _ObservationsFeed extends StatelessWidget {
  const _ObservationsFeed({
    required this.entries,
    required this.allCount,
    required this.groups,
    required this.groupFilter,
    required this.onFilterChanged,
  });

  final List<Entry> entries;
  final int allCount;
  final List<Group> groups;
  final String? groupFilter;
  final ValueChanged<String?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    // Bucket entries by local day so we can pin a "Today / Yesterday /
    // Tuesday May 19" header between groups.
    final byDay = <String, List<Entry>>{};
    final dayOrder = <String>[];
    for (final e in entries) {
      final dt = DateTime.tryParse(e.recordedAt)?.toLocal();
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month}-${dt.day}';
      if (!byDay.containsKey(key)) {
        dayOrder.add(key);
        byDay[key] = [];
      }
      byDay[key]!.add(e);
    }

    // Cap + center the day-grouped feed on desktop/web (was full-width).
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.splitMaxWidth),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: 'Observations',
                  subtitle: _subtitleFor(entries.length, groupFilter, groups),
                  bottomGap: 8,
                ),
              ),
            ),
            // Classroom chip row — horizontal scroll, single-tap toggle.
            if (groups.length > 1)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _ClassroomChip(
                        label: 'All',
                        selected: groupFilter == null,
                        onTap: () => onFilterChanged(null),
                      ),
                      for (final g in groups)
                        _ClassroomChip(
                          label: g.name,
                          selected: groupFilter == g.id,
                          onTap: () => onFilterChanged(g.id),
                        ),
                    ],
                  ),
                ),
              ),
            if (entries.isEmpty && allCount > 0)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No observations match this filter',
                ),
              ),
            for (final key in dayOrder) ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: _DayHeader(label: _dayLabel(key)),
              ),
              SliverList.builder(
                itemCount: byDay[key]!.length,
                itemBuilder: (_, i) => _ObservationListItem(
                  entry: byDay[key]![i],
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  static String _dayLabel(String key) {
    final parts = key.split('-').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((p) => p == null)) return key;
    final d = DateTime(parts[0]!, parts[1]!, parts[2]!);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final delta = today.difference(d).inDays;
    if (delta == 0) return 'Today';
    if (delta == 1) return 'Yesterday';
    if (delta < 7) {
      const dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return dayNames[d.weekday - 1];
    }
    return '${d.month}/${d.day}/${d.year % 100}';
  }

  static String _subtitleFor(int count, String? groupId, List<Group> groups) {
    final base = count == 1 ? '1 entry' : '$count entries';
    if (groupId == null) return '$base · all classrooms';
    final match = groups.where((g) => g.id == groupId).firstOrNull;
    final name = match?.name ?? '—';
    return '$base · $name';
  }
}

class _ClassroomChip extends StatelessWidget {
  const _ClassroomChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends SliverPersistentHeaderDelegate {
  _DayHeader({required this.label});
  final String label;

  @override
  double get minExtent => 36;
  @override
  double get maxExtent => 36;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeader old) => old.label != label;
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
    final when = DateTime.tryParse(entry.recordedAt)?.toLocal();
    final whenLabel = relativeTimeAgo(when);

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
            maxLines: 3,
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
      onTap: () => context.push(
        '/observations/${entry.id}/edit',
        extra: entry,
      ),
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
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: PersonPhotoNetwork(
                  urlOrPath: photos.first,
                  errorBuilder: (_) => const Icon(Icons.broken_image_outlined),
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
