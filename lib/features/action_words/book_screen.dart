import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:differentworld/features/story/widgets/moment_tile.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/book/:subjectId` — a child's **Book**: their 10-week journey, grouped
/// by the curriculum week each moment was captured in. World by world, the
/// verbs they practiced and the moments the room caught — the growing
/// keepsake the curriculum builds toward ("the last page", Week 10). Composes
/// the existing Story moments over the world schedule; no new data.
class BookScreen extends ConsumerWidget {
  const BookScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    final firstName = subject?.firstName ?? 'This child';
    final start = ref.watch(programStartDateProvider);
    final worlds = ref.watch(curriculumWorldsProvider).value ?? const [];
    final entriesAsync = ref.watch(
      entriesForSubjectProvider((subjectId: subjectId, kind: null)),
    );

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: start == null
          ? EmptyState(
              icon: Icons.auto_stories_outlined,
              title: '$firstName’s book starts soon',
              message: 'Once the 10-week journey is set up, $firstName’s book '
                  'fills in week by week — the worlds they visit and the '
                  'moments along the way.',
            )
          : entriesAsync.when(
              loading: () => const LoadingSlot(),
              error: (_, _) => ErrorState(
                title: 'Could not load the book',
                onRetry: () => ref.invalidate(
                  entriesForSubjectProvider(
                    (subjectId: subjectId, kind: null),
                  ),
                ),
              ),
              data: (entries) =>
                  _Book(firstName: firstName, entries: entries,
                      start: start, worlds: worlds),
            ),
    );
  }
}

class _Book extends StatelessWidget {
  const _Book({
    required this.firstName,
    required this.entries,
    required this.start,
    required this.worlds,
  });

  final String firstName;
  final List<Entry> entries;
  final DateTime start;
  final List<CurriculumWorld> worlds;

  @override
  Widget build(BuildContext context) {
    // Group every captured moment by the curriculum week it happened in.
    final byWeek = <int, List<Entry>>{};
    for (final e in entries) {
      final local = DateTime.tryParse(e.recordedAt)?.toLocal();
      if (local == null) continue;
      final week = curriculumWeekFor(start, local);
      if (week == null) continue;
      byWeek.putIfAbsent(week, () => []).add(e);
    }

    if (byWeek.isEmpty) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: '$firstName’s book is blank — for now',
        message: 'As the room captures moments — picks, photos, observations '
            '— they’ll land here, sorted into the week’s world.',
      );
    }

    final weeks = byWeek.keys.toList()..sort();
    var totalMoments = 0;
    for (final w in weeks) {
      totalMoments += momentsFrom(byWeek[w]!).length;
    }

    return ResponsivePage(
      children: [
        ContentHeader(
          title: '$firstName’s book',
          subtitle: 'The 10-week journey, week by week',
        ),
        for (final week in weeks)
          _WeekSection(
            week: week,
            world: _worldFor(week),
            entries: byWeek[week]!,
          ),
        _LastPage(
          firstName: firstName,
          worldsVisited: weeks.length,
          moments: totalMoments,
        ),
      ],
    );
  }

  CurriculumWorld? _worldFor(int week) {
    for (final w in worlds) {
      if (w.week == week) return w;
    }
    return null;
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({
    required this.week,
    required this.world,
    required this.entries,
  });

  final int week;
  final CurriculumWorld? world;
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = world?.color ?? theme.colorScheme.primary;
    final moments = momentsFrom(entries).reversed.toList(); // oldest first
    final verbs = _practicedVerbs(entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Row(
            children: [
              Text(world?.emoji ?? '🌍', style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week $week${world == null ? '' : ' · ${world!.name}'}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (world != null)
                      Text(
                        world!.question,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (verbs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in verbs)
                if (verbById(id) case final v?)
                  Chip(
                    label: Text('${v.emoji} ${v.label}'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        for (final m in moments) MomentTile(moment: m),
        const SizedBox(height: 8),
      ],
    );
  }

  List<String> _practicedVerbs(List<Entry> entries) {
    final seen = <String>{};
    final out = <String>[];
    for (final e in entries) {
      if (e.kind != EntryKind.actionWords) continue;
      final day = ActionWordsDay.fromEntry(e);
      for (final v in {...day.done, ...day.verbPicks}) {
        if (seen.add(v)) out.add(v);
      }
    }
    return out;
  }
}

class _LastPage extends StatelessWidget {
  const _LastPage({
    required this.firstName,
    required this.worldsVisited,
    required this.moments,
  });

  final String firstName;
  final int worldsVisited;
  final int moments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('✨', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'So far in $firstName’s book',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '$worldsVisited ${worldsVisited == 1 ? 'world' : 'worlds'} '
              'visited · $moments ${moments == 1 ? 'moment' : 'moments'} '
              'captured',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
