import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/hover_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// A child's **Story** — every moment the room captured (observations,
/// the Action Words world, missions, roles, incidents, snacks, naps,
/// photos), woven into one continuous, date-grouped timeline. This is the
/// memory: the day-to-day doing IS the capture, and the capture grows into
/// the story (the answer to "how do we capture stories / continuity").
class KidStoryScreen extends ConsumerWidget {
  const KidStoryScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    final firstName = subject?.firstName ?? 'This child';
    final entriesAsync = ref.watch(
      entriesForSubjectProvider((subjectId: subjectId, kind: null)),
    );

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: entriesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the story',
          onRetry: () => ref.invalidate(
            entriesForSubjectProvider((subjectId: subjectId, kind: null)),
          ),
        ),
        data: (entries) {
          final moments = momentsFrom(entries);
          if (moments.isEmpty) {
            return EmptyState(
              icon: Icons.auto_stories_outlined,
              title: '$firstName’s story starts here',
              message: 'Every observation, world, mission, and photo you '
                  'capture lands here — the story grows as the days go by.',
            );
          }
          final items = _groupByDay(moments);
          return Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: Breakpoints.splitMaxWidth),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: items.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: ContentHeader(
                        title: '$firstName’s story',
                        subtitle: moments.length == 1
                            ? '1 moment'
                            : '${moments.length} moments',
                      ),
                    );
                  }
                  final item = items[i - 1];
                  return item.header != null
                      ? _DayHeader(label: item.header!)
                      : _MomentTile(moment: item.moment!);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Row {
  const _Row.header(this.header) : moment = null;
  const _Row.moment(this.moment) : header = null;
  final String? header;
  final Moment? moment;
}

/// Flatten moments (newest-first) into header + moment rows, inserting a
/// day header (Today / Yesterday / weekday / date) when the day changes.
List<_Row> _groupByDay(List<Moment> moments) {
  final rows = <_Row>[];
  String? lastKey;
  for (final m in moments) {
    final when = m.when;
    final key = when == null ? '—' : dateKey(when);
    if (key != lastKey) {
      rows.add(_Row.header(when == null ? 'Earlier' : _dayLabel(when)));
      lastKey = key;
    }
    rows.add(_Row.moment(m));
  }
  return rows;
}

String _dayLabel(DateTime when) {
  final now = DateTime.now();
  final d = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return DateFormat.EEEE().format(when);
  return DateFormat.yMMMMd().format(when);
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MomentTile extends ConsumerWidget {
  const _MomentTile({required this.moment});
  final Moment moment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final when = moment.when;
    final photos = moment.showsPhotos
        ? (ref
                .watch(attachmentsForEntityProvider(
                  (kind: 'entry', id: moment.id),
                ))
                .value
                ?.urls ??
            const <String>[])
        : const <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The spine + dot.
          Column(
            children: [
              Text(moment.emoji, style: const TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          moment.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (when != null)
                        Text(
                          timeOfDay(when),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (moment.body != null) ...[
                    const SizedBox(height: 4),
                    Text(moment.body!),
                  ],
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _PhotoStrip(urls: photos),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => HoverTap(
          onTap: () => PhotoViewer.open(context, urls: urls, initialIndex: i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 96,
              child: PersonPhotoNetwork(
                urlOrPath: urls[i],
                errorBuilder: (_) => Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
