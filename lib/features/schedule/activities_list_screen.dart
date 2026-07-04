import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/catalog_card.dart';
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the catalog re-lays as a dense
    // responsive grid over the SAME provider data; off keeps the existing
    // CatalogGrid (which already re-packs by width).
    final bento = bentoEnabled(ref, perScreen: null);
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
          return ResponsivePage(
            children: [
              const ContentHeader(
                title: 'Activities',
                subtitle:
                    'What kids do during scheduled blocks. Reusable; '
                    'teachers add their own.',
              ),
              const SizedBox(height: 4),
              if (bento)
                _ActivitiesBentoGrid(activities: activities)
              else
                CatalogGrid(
                  children: [
                    for (final a in activities) _ActivityCard(activity: a),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The bento variant — SAME activities, re-laid as a dense responsive
/// `GridView.builder`. Activity cards are text-heavy (a description line +
/// up to five meta chips), so a 180dp 2-up phone cell would truncate; a
/// ~240dp max-extent keeps them 1-up on a phone and 2-up on a tablet (the
/// GRID.md "text-heavy → wider cell" rule). The cell height grows with the
/// text-size setting so chips never overflow a fixed-aspect box.
class _ActivitiesBentoGrid extends StatelessWidget {
  const _ActivitiesBentoGrid({required this.activities});

  final List<Activity> activities;

  @override
  Widget build(BuildContext context) {
    // 1.0 at the OS default; cells grow as the user scales text up.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Generous floor: name (2 lines) + description (2 lines) + a chip
        // run, growing with text scale so nothing clips in a fixed cell.
        mainAxisExtent: 168 + 56 * scale,
      ),
      itemCount: activities.length,
      itemBuilder: (context, i) {
        final a = activities[i];
        return _ActivityCard(
          key: ValueKey('activity-${a.id}'),
          activity: a,
        );
      },
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({required this.activity, super.key});

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return CatalogCard(
      leading: CatalogIcon.icon(
        isOutdoor ? Icons.park_outlined : Icons.local_activity_outlined,
      ),
      title: activity.name,
      titleWidget: EntityLink(
        entity: EntityRef(
          kind: EntityKind.activity,
          id: activity.id,
          label: activity.name,
        ),
        padded: false,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: activity.description,
      chips: chips,
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
