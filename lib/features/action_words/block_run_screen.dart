import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/block_run.dart';
import 'package:differentworld/features/action_words/widgets/block_handoff.dart';
import 'package:differentworld/features/action_words/widgets/day_arc_strip.dart';
import 'package:differentworld/features/action_words/widgets/deck_overview.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/run-day` — **the day, on rails, from your live schedule.** The synthesis
/// in docs/VISION.md ("the whole day is one ordered deck — an arc from open to
/// close"): today's `schedule_blocks` become an ordered run of show the teacher
/// advances through. Built on the same content-agnostic [DeckOverview] +
/// `BeatPresenter` engine `/play-today` uses — this just feeds it the schedule
/// (via [buildBlockRun]) instead of the curriculum world.
///
/// Scopes to the viewer's group: one cohort runs straight through; with several,
/// a cohort switcher rides the actions pill. A block carrying a curriculum
/// session is flagged as runnable (its own beat deck is the next slice).
class BlockRunScreen extends ConsumerStatefulWidget {
  const BlockRunScreen({super.key});

  @override
  ConsumerState<BlockRunScreen> createState() => _BlockRunScreenState();
}

class _BlockRunScreenState extends ConsumerState<BlockRunScreen> {
  /// null = the viewer's first cohort; otherwise the chosen one.
  String? _groupId;

  Group? _resolve(List<Group> groups) {
    for (final g in groups) {
      if (g.id == _groupId) return g;
    }
    return groups.isEmpty ? null : groups.first;
  }

  Future<void> _pickGroup(BuildContext context, List<Group> groups) async {
    final picked = await showGlassSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in groups)
              ListTile(
                title: Text(g.name),
                trailing: g.id == _resolve(groups)?.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop(g.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _groupId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);
    // The day wears this week's world colour when one is live, so the run
    // shares the week's hue; a neutral theme accent otherwise.
    final accent =
        ref.watch(currentWorldProvider)?.color ??
        Theme.of(context).colorScheme.primary;
    final groups = groupsAsync.value ?? const <Group>[];

    return EdgeScaffold(
      actions: [
        if (groups.length > 1)
          IconButton(
            tooltip: 'Choose cohort',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => unawaited(_pickGroup(context, groups)),
          ),
        const SyncStatusIndicator(),
      ],
      body: groupsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load your classrooms',
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        data: (gs) {
          if (gs.isEmpty) {
            return const EmptyState(
              icon: Icons.school_outlined,
              title: 'No classrooms yet',
              message:
                  'Create a classroom and build its day, then run it from here.',
            );
          }
          return _BlockDayDeck(group: _resolve(gs)!, accent: accent);
        },
      ),
    );
  }
}

/// The selected cohort's day, today — its blocks as the tappable run deck.
class _BlockDayDeck extends ConsumerWidget {
  const _BlockDayDeck({required this.group, required this.accent});

  final Group group;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (groupId: group.id, date: todayKey());
    final blocksAsync = ref.watch(scheduleDayForGroupProvider(key));

    return blocksAsync.when(
      loading: () => const LoadingSlot(),
      error: (_, _) => ErrorState(
        title: "Couldn't load today's schedule",
        onRetry: () => ref.invalidate(scheduleDayForGroupProvider(key)),
      ),
      data: (blocks) {
        final inputs = [
          for (final b in blocks)
            (
              blockId: b.id,
              title: b.title ?? '',
              startAt: b.startAt,
              endAt: b.endAt,
              kind: b.kind,
              notes: b.notes,
              sessionSlug: b.curriculumSessionSlug,
              status: b.status,
            ),
        ];
        // ONE aligned pass: run.beats[i] is built from run.ordered[i], so a
        // tapped tile index resolves back to its source block for the drill.
        final run = buildBlockRunAligned(inputs);
        final beats = run.beats;
        final ordered = run.ordered;

        if (beats.isEmpty) {
          return EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No blocks scheduled today',
            message:
                '${group.name} has nothing on the schedule yet. Build the day, '
                'then run it from here.',
            action: FilledButton.icon(
              onPressed: () => context.push('/schedule'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Open schedule'),
            ),
          );
        }

        return DeckOverview(
          beats: beats,
          accent: accent,
          title: 'Run the day',
          subtitle:
              '${group.name} · ${beats.length} ${beats.length == 1 ? 'block' : 'blocks'}',
          arc: DayArcStrip(energies: [for (final b in beats) b.energy], accent: accent),
          onPresent: (i) {
            // A block carrying a curriculum session drills into its own beat
            // deck (the nested level from the mockups); a plain block presents
            // the run from here.
            final slug = ordered[i].sessionSlug?.trim() ?? '';
            if (slug.isNotEmpty) {
              unawaited(
                context.push(
                  '/session/run?slug=${Uri.encodeQueryComponent(slug)}'
                  '&block=${Uri.encodeQueryComponent(ordered[i].blockId)}',
                ),
              );
              return;
            }
            unawaited(
              context.push(
                '/run-day/present',
                extra: DeckPresentArgs(
                  beats: beats,
                  accent: accent,
                  initialBeat: i,
                  onFinished: (context, dismiss) => BlockHandoff(
                    justFinishedTitle: '${group.name} · today',
                    accent: accent,
                    onDismiss: dismiss,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
