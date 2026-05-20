import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Pre-block brief" — the 30-second card a specialist (or any block
/// lead) opens before their block starts. Single-screen, no scroll
/// needed for typical cohort sizes. Shows:
///
///   - Time + location + activity name + duration.
///   - Roster of kids in the cohort, with allergies highlighted.
///   - Supplies the activity requires.
///   - Notes the scheduler attached.
///
/// Reached from the staff Today's "Leading today" card, from the
/// schedule screen by tapping a block, and (in v2) from a push
/// notification 10 min before the block starts.
class PreBlockBriefSheet extends ConsumerWidget {
  const PreBlockBriefSheet({required this.blockId, super.key});

  final String blockId;

  static Future<void> show(BuildContext context, String blockId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => PreBlockBriefSheet(blockId: blockId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final blockAsync = ref.watch(_blockByIdProvider(blockId));
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final locations =
        ref.watch(locationsProvider).value ?? const <Location>[];

    return blockAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox(
        height: 120,
        child: Center(child: Text('Could not load the block.')),
      ),
      data: (block) {
        if (block == null) {
          return const SizedBox(
            height: 120,
            child: Center(child: Text('Block not found.')),
          );
        }
        final start = DateTime.parse(block.startAt).toLocal();
        final end = DateTime.parse(block.endAt).toLocal();
        final activity = block.activityId == null
            ? null
            : activities
                .where((a) => a.id == block.activityId)
                .firstOrNull;
        final loc = block.locationOverrideId != null
            ? locations
                .where((l) => l.id == block.locationOverrideId)
                .firstOrNull
            : (activity?.defaultLocationId == null
                ? null
                : locations
                    .where((l) => l.id == activity!.defaultLocationId)
                    .firstOrNull);

        final subjectsAsync =
            ref.watch(subjectsInGroupProvider(block.groupId));
        final subjects =
            subjectsAsync.value ?? const <Subject>[];

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: activity + time + location, all visible at
              // a glance. No scroll for this section.
              Row(
                children: [
                  Icon(
                    block.kind == 'field_trip'
                        ? Icons.directions_bus_outlined
                        : Icons.local_activity_outlined,
                    color: scheme.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity?.name ??
                              (block.kind == 'break' ? 'Break' : '—'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_t(start)}–${_t(end)} · '
                          '${end.difference(start).inMinutes} min'
                          '${loc == null ? '' : ' · ${loc.name}'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (activity?.description != null &&
                  activity!.description!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  activity.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],

              // Roster — the meat. Allergies highlighted so the
              // specialist doesn't have to drill in per kid.
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Your group',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${subjects.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (subjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No students in this cohort yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: subjects.length,
                    itemBuilder: (_, i) {
                      final s = subjects[i];
                      final allergies = s.allergies?.trim() ?? '';
                      final hasAllergy = allergies.isNotEmpty;
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            PersonAvatar(
                              name: '${s.firstName} ${s.lastName}',
                              photoUrl: s.photoUrl,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${s.firstName} ${s.lastName}',
                                    style:
                                        theme.textTheme.bodyMedium,
                                  ),
                                  if (hasAllergy)
                                    Text(
                                      'Allergy: $allergies',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: scheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (hasAllergy)
                              Icon(
                                Icons.warning_amber_rounded,
                                color: scheme.error,
                                size: 18,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              // Supplies — what to bring. From the activity's
              // free-text supplies field.
              if (activity?.supplies != null &&
                  activity!.supplies!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer
                        .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.backpack_outlined,
                        color: scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supplies',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(
                                color: scheme.onTertiaryContainer,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activity.supplies!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Notes — scheduler's per-block notes ("watch Ari's
              // shoulder", "use the deep end today").
              if (block.notes != null && block.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        color: scheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          block.notes!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _t(DateTime when) {
    final h = when.hour.toString().padLeft(2, '0');
    final m = when.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Watches a single schedule block by id. Lives inline because the
/// brief sheet is the only consumer.
// ignore: specify_nonobvious_property_types
final _blockByIdProvider =
    StreamProvider.autoDispose.family<ScheduleBlock?, String>(
        (ref, id) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.scheduleDao.watchById(id);
});
