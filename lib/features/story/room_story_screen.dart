import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/story/moment.dart';
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

/// The **room Story** — the whole class's moments (every child, every
/// kind), woven into one day-grouped timeline. The room's living memory:
/// scroll back through the days and see what the room did.
class RoomStoryScreen extends ConsumerWidget {
  const RoomStoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentsAsync = ref.watch(spaceMomentsProvider);
    final subjectsById = <String, Subject>{
      for (final s
          in ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[])
        s.id: s,
    };

    return EdgeScaffold(
      actions: [
        IconButton(
          tooltip: 'Wrap',
          icon: const Icon(Icons.auto_awesome_motion_outlined),
          onPressed: () => WrapSheet.show(context, subjectName: 'The room'),
        ),
        const SyncStatusIndicator(),
      ],
      body: momentsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the room story',
          onRetry: () => ref.invalidate(spaceMomentsProvider),
        ),
        data: (entries) {
          final moments = momentsFrom(entries);
          if (moments.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'The room’s story starts here',
              message: 'Observations, worlds, missions, and photos from '
                  'across the room land here, growing day by day.',
            );
          }
          return StoryTimeline(
            title: 'Room story',
            moments: moments,
            subjectsById: subjectsById,
          );
        },
      ),
    );
  }
}
