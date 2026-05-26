import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/activities` — the catalog of activities staff have authored.
/// Teachers create their own; activities are reusable across schedule
/// blocks.
class ActivitiesListScreen extends ConsumerWidget {
  const ActivitiesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);
    // Activities are a teacher-authored catalog — anyone in the staff
    // lens curates them. The schedule itself is the canManageSchedule
    // gate; archive/destruction of catalog entries is light enough to
    // share. Director-only locks would mean a teacher couldn't add
    // their own activity, which contradicts the design intent.
    final viewer = ref.watch(viewerProvider);
    final canEdit = viewer.member != null;
    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: [
        if (canEdit)
          PrimaryActionButton(
            tooltip: 'New activity',
            icon: Icons.add,
            onPressed: () => context.push('/activities/new'),
          ),
      ],
      body: activitiesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load activities',
          onRetry: () => ref.invalidate(activitiesProvider),
        ),
        data: (activities) {
          if (activities.isEmpty) {
            return EmptyState(
              icon: Icons.local_activity_outlined,
              title: 'No activities yet',
              message:
                  "Build your camp's catalog — swimming, archery, art, "
                  'nature walk. Once they exist here you can drop them '
                  'into the schedule.',
              action: canEdit
                  ? FilledButton.icon(
                      onPressed: () => context.push('/activities/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add activity'),
                    )
                  : null,
            );
          }
          return ResponsivePage.builder(
            itemCount: activities.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Activities',
                    subtitle:
                        'What kids do during scheduled blocks. Reusable; '
                        'teachers add their own.',
                    bottomGap: 8,
                  ),
                );
              }
              return _ActivityTile(activity: activities[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isOutdoor = activity.isOutdoor == 1;

    // Resolve the default location's name (live) so the chip stays
    // current when the location renames.
    final loc = activity.defaultLocationId == null
        ? null
        : (ref.watch(locationsProvider).value ?? const <Location>[])
              .where((l) => l.id == activity.defaultLocationId)
              .firstOrNull;

    final chips = <Widget>[
      if (loc != null) _MetaChip(icon: Icons.place_outlined, label: loc.name),
      if (activity.defaultDurationMinutes != null)
        _MetaChip(
          icon: Icons.timer_outlined,
          label: '${activity.defaultDurationMinutes} min',
        ),
      if (activity.ageMin != null || activity.ageMax != null)
        _MetaChip(
          icon: Icons.child_care_outlined,
          label: _ageBandLabel(activity.ageMin, activity.ageMax),
        ),
      if (activity.maxCapacity != null)
        _MetaChip(
          icon: Icons.group_outlined,
          label: 'cap ${activity.maxCapacity}',
        ),
      if (isOutdoor)
        const _MetaChip(icon: Icons.park_outlined, label: 'outdoor'),
    ];

    return ListTile(
      isThreeLine: chips.isNotEmpty,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(
          isOutdoor ? Icons.park_outlined : Icons.local_activity_outlined,
          color: scheme.onPrimaryContainer,
        ),
      ),
      title: Text(activity.name),
      subtitle: chips.isEmpty
          ? (activity.description == null
                ? const Text('—')
                : Text(
                    activity.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ))
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 4, runSpacing: 4, children: chips),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/activities/${activity.id}'),
    );
  }

  static String _ageBandLabel(int? min, int? max) {
    if (min != null && max != null) return '$min–$max';
    if (min != null) return '$min+';
    if (max != null) return 'up to $max';
    return '';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
