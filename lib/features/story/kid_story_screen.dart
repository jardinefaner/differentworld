import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/story/story_providers.dart';
import 'package:differentworld/features/story/widgets/story_timeline.dart';
import 'package:differentworld/features/story/widgets/wrap_sheet.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A child's **Story** — every moment the room captured (observations,
/// the Action Words world, missions, roles, incidents, snacks, naps,
/// photos), woven into one continuous, date-grouped timeline. This is the
/// memory: the day-to-day doing IS the capture, and the capture grows into
/// the story.
class KidStoryScreen extends ConsumerWidget {
  const KidStoryScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    final firstName = subject?.firstName ?? 'This child';
    final momentsAsync = ref.watch(momentsForSubjectProvider(subjectId));

    return EdgeScaffold(
      actions: [
        IconButton(
          tooltip: 'Play the story',
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () => context.push('/story/$subjectId/play'),
        ),
        IconButton(
          tooltip: 'Character sheet',
          icon: const Icon(Icons.badge_outlined),
          onPressed: () => context.push('/subjects/$subjectId/me'),
        ),
        IconButton(
          tooltip: 'Book — the 10-week journey',
          icon: const Icon(Icons.auto_stories_outlined),
          onPressed: () => context.push('/book/$subjectId'),
        ),
        IconButton(
          tooltip: 'Wrap',
          icon: const Icon(Icons.auto_awesome_motion_outlined),
          onPressed: () => WrapSheet.show(
            context,
            subjectName: firstName,
            subjectId: subjectId,
          ),
        ),
        const SyncStatusIndicator(),
      ],
      body: momentsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the story',
          onRetry: () => ref.invalidate(
            entriesForSubjectProvider((subjectId: subjectId, kind: null)),
          ),
        ),
        data: (moments) {
          if (moments.isEmpty) {
            return EmptyState(
              icon: Icons.auto_stories_outlined,
              title: '$firstName’s story starts here',
              message: 'Every observation, world, mission, and photo you '
                  'capture lands here — the story grows as the days go by.',
            );
          }
          return StoryTimeline(
            title: '$firstName’s story',
            moments: moments,
          );
        },
      ),
    );
  }
}
