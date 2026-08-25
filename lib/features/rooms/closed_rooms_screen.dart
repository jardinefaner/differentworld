import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rooms that have been retired (docs/ROOMS.md).
///
/// The way back. Closing a room is only safe to offer as the primary action
/// because reopening it is one tap from here — otherwise "close" would be a
/// one-way door wearing a friendlier label than "delete".
class ClosedRoomsScreen extends ConsumerWidget {
  const ClosedRoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(verticalLabelsProvider);
    final closedAsync = ref.watch(closedGroupsProvider);
    final word = labels.groupPlural.toLowerCase();

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: closedAsync.when(
              loading: () => const LoadingSlot(),
              error: (_, _) => ErrorState(
                title: 'Could not load closed $word',
                onRetry: () => ref.invalidate(closedGroupsProvider),
              ),
              data: (rooms) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  ContentHeader(
                    title: 'Closed $word',
                    subtitle: rooms.isEmpty
                        ? 'Nothing has been retired yet.'
                        : '${rooms.length} retired · everything kept',
                  ),
                  if (rooms.isEmpty)
                    EmptyState(
                      icon: Icons.archive_outlined,
                      title: 'No closed $word',
                      message:
                          'When you stop running a room, close it instead of '
                          'deleting it — it keeps its schedule and its whole '
                          'history, and lands here.',
                    )
                  else
                    for (final g in rooms) _ClosedRow(group: g, labels: labels),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosedRow extends ConsumerWidget {
  const _ClosedRow({required this.group, required this.labels});

  final Group group;
  final VerticalLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureCard(
      leading: const Icon(Icons.meeting_room_outlined),
      title: group.name,
      subtitle: group.ageRange ?? 'Closed',
      trailing: TextButton(
        onPressed: () => unawaited(_reopen(context, ref)),
        child: const Text('Reopen'),
      ),
      onTap: () => unawaited(_reopen(context, ref)),
    );
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(groupActionsProvider).reopenRoom(group.id);
    messenger.showSnackBar(
      SnackBar(content: Text('${group.name} is back in today’s rosters.')),
    );
  }
}
