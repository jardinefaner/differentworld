import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/entries/widgets/observation_form_sheet.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    if (!viewer.canObserve && !viewer.canManageProgram) {
      return const EdgeScaffold(body: NoAccess());
    }

    final group = groupAsync.value;
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load observations',
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
                      onPressed: () => ObservationFormSheet.show(
                        context,
                        groupId: groupId,
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
      floatingActionButton: viewer.canObserve
          ? FloatingActionButton.extended(
              onPressed: () {
                unawaited(HapticFeedback.mediumImpact());
                unawaited(ObservationFormSheet.show(context, groupId: groupId));
              },
              icon: const Icon(Icons.add),
              label: const Text('Observation'),
            )
          : null,
    );
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _groupForObsProvider = StreamProvider.autoDispose.family<Group?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchGroup(id);
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
      isThreeLine: true,
      onTap: () => ObservationFormSheet.show(
        context,
        existing: entry,
      ),
    );
  }
}
