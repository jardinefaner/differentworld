import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// `/subjects/:id/trail` — a child's cumulative WORK over time, the "time-lapse"
/// the user asked for: everything they've made (the role-card captures + snapped
/// paper), newest day on top, with a day-bar filmstrip that visibly grows as
/// the weeks accrue. Reads only their `work_sample` entries — the child's own
/// made things — so no other-child free-text is in view (the family-scrub class,
/// CLAUDE.md). Staff-facing for now.
///
/// The day sections are LAZY (a `SliverGrid` per day), so each [_TrailPiece]
/// thumbnail mints its signed URL only as it scrolls into view — no eager
/// burst when a long-tenured child's trail opens. No piece cap is needed.
class ChildTrailScreen extends ConsumerWidget {
  const ChildTrailScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(subjectByIdProvider(subjectId)).value?.firstName;
    final samplesAsync = ref.watch(
      entriesForSubjectProvider((subjectId: subjectId, kind: EntryKind.workSample)),
    );

    return EdgeScaffold(
      body: SafeArea(
        bottom: false,
        child: samplesAsync.when(
          loading: () => const LoadingSlot(),
          error: (_, _) => const EmptyState(
            icon: Icons.collections_outlined,
            title: 'Could not load the trail',
            message: 'Pull back in a moment.',
          ),
          data: (all) {
            // Newest first — the trail reads top-down as most-recent-day first.
            final samples = [...all]
              ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
            if (samples.isEmpty) {
              return EmptyState(
                icon: Icons.auto_awesome_outlined,
                title: 'Nothing on the trail yet',
                message:
                    'Practise a role with ${name ?? 'this child'} — each tool '
                    '(draw, snap, note) lands a piece here, and the trail grows '
                    'from there.',
              );
            }

            // Group by local calendar day (insertion order = newest-first).
            final byDay = <String, List<Entry>>{};
            for (final e in samples) {
              final local = DateTime.tryParse(e.recordedAt)?.toLocal();
              final key = local == null ? '—' : dateKey(local);
              (byDay[key] ??= <Entry>[]).add(e);
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ContentHeader(
                          title: name != null ? '$name’s trail' : 'The trail',
                          subtitle: _summary(byDay.length, samples.length),
                        ),
                        _Filmstrip(samples: samples),
                      ],
                    ),
                  ),
                ),
                // One label + lazy grid per day. The SliverGrid builds only the
                // on-screen tiles, so each piece mints its signed URL as it
                // scrolls into view — no eager burst, no piece cap.
                for (final day in byDay.entries) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    sliver: SliverToBoxAdapter(child: _DayLabel(dayKey: day.key)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 116,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _TrailPiece(entry: day.value[i]),
                        childCount: day.value.length,
                      ),
                    ),
                  ),
                ],
                // Clear the floating omnibox bar.
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }

  String _summary(int days, int total) {
    final pieces = total == 1 ? '1 piece' : '$total pieces';
    final dayLabel = days == 1 ? '1 day' : '$days days';
    return '$pieces · $dayLabel, and counting';
  }
}

/// The day-bar filmstrip — one bar per calendar day across the last two weeks,
/// height ∝ how much was made that day. The whole arc at a glance: the bars on
/// the right fill in as the days go by (the "time-lapse" read).
class _Filmstrip extends StatelessWidget {
  const _Filmstrip({required this.samples});

  final List<Entry> samples;

  static const _days = 14;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counts = <String, int>{};
    for (final e in samples) {
      final local = DateTime.tryParse(e.recordedAt)?.toLocal();
      if (local == null) continue;
      final key = dateKey(local);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final today = DateTime.now();
    // Oldest → newest, left → right, so the trail "grows" toward the right edge.
    final bars = <int>[];
    for (var i = _days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      bars.add(counts[dateKey(day)] ?? 0);
    }
    final maxCount = bars.fold<int>(1, (m, c) => c > m ? c : m);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final c in bars)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: FractionallySizedBox(
                        heightFactor: (c / maxCount).clamp(0.06, 1.0),
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c == 0
                                ? scheme.surfaceContainerHighest
                                : scheme.primary.withValues(
                                    alpha: 0.35 + 0.65 * (c / maxCount),
                                  ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'each bar a day — the trail grows',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A day's relative-day heading (Today / Yesterday / a full date), above that
/// day's lazy grid of pieces.
class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.dayKey});

  final String dayKey;

  String get _label {
    if (dayKey == '—') return 'Earlier';
    if (dayKey == todayKey()) return 'Today';
    final y = DateTime.now().subtract(const Duration(days: 1));
    if (dayKey == dateKey(y)) return 'Yesterday';
    final parsed = DateTime.tryParse(dayKey);
    return parsed == null ? dayKey : DateFormat.MMMMEEEEd().format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Text(_label, style: Theme.of(context).textTheme.titleSmall);
  }
}

/// One captured piece. A photo/drawing renders as a tappable thumbnail (full
/// view on tap, signed URL via [PersonPhotoNetwork]); a note-only capture
/// renders as a small card showing the child's own words.
class _TrailPiece extends ConsumerWidget {
  const _TrailPiece({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final urls = ref
            .watch(attachmentsForEntityProvider((kind: 'entry', id: entry.id)))
            .value
            ?.urls ??
        const <String>[];

    if (urls.isEmpty) {
      // A note-only piece — the child's own caption (safe to show: their words,
      // not staff free-text about others).
      final note = (entry.body ?? '').trim();
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.edit_note_outlined,
              size: 18,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                note.isEmpty ? 'A note' : note,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Fills the grid cell. Stack(expand) so the photo covers the cell and the
    // InkWell overlay catches the tap (the work_gallery pattern).
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: theme.colorScheme.surfaceContainerHigh,
            child: PersonPhotoNetwork(
              urlOrPath: urls.first,
              errorBuilder: (_) => const Center(
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => PhotoViewer.open(context, urls: urls),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
