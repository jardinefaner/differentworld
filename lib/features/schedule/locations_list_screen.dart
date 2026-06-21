import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
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

/// `/settings/locations` — registry of physical places activities
/// happen. Authoritative for both the activity edit screen (where each
/// activity picks a default location) and the schedule block sheet
/// (which can override the location per block).
///
/// Create / edit a location is its own PAGE (`/settings/locations/new`,
/// `:id/edit`) — the `LocationEditScreen` page — not a bottom sheet
/// (CLAUDE.md "No modal is a task").
class LocationsListScreen extends ConsumerWidget {
  const LocationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationsAsync = ref.watch(locationsProvider);
    final canEdit = ref.watch(viewerProvider).canManageSpace;
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the locations re-lay as a dense
    // responsive card grid (2-up on a phone) over the SAME provider data; off
    // keeps the existing ListTile list.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: [
        if (canEdit)
          PrimaryActionButton(
            tooltip: 'New location',
            icon: Icons.add,
            onPressed: () => unawaited(context.push('/settings/locations/new')),
          ),
      ],
      body: locationsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load locations',
          onRetry: () => ref.invalidate(locationsProvider),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return EmptyState(
              icon: Icons.place_outlined,
              title: 'No locations yet',
              message:
                  'Add the places activities happen — pool, art barn, '
                  'archery range. Activities reuse them; the scheduler '
                  'warns when a cohort is booked into a too-small room.',
              action: canEdit
                  ? FilledButton.icon(
                      onPressed: () =>
                          unawaited(context.push('/settings/locations/new')),
                      icon: const Icon(Icons.add),
                      label: const Text('Add location'),
                    )
                  : null,
            );
          }
          if (bento) {
            return ResponsivePage(
              children: [
                const ContentHeader(
                  title: 'Locations',
                  subtitle: 'Where activities happen on camp grounds',
                  bottomGap: 8,
                ),
                _LocationsBentoGrid(locations: locations, canEdit: canEdit),
              ],
            );
          }
          return ResponsivePage.builder(
            itemCount: locations.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Locations',
                    subtitle: 'Where activities happen on camp grounds',
                    bottomGap: 8,
                  ),
                );
              }
              return _LocationTile(
                location: locations[i - 1],
                canEdit: canEdit,
              );
            },
          );
        },
      ),
    );
  }
}

/// The bento variant — SAME locations, re-laid as a dense responsive
/// `GridView.builder`. A location is short (a name + a "cap. 24 · outdoor"
/// line), so a 180dp max-extent packs them 2-up on a phone. A `ListTile` is
/// list-shaped and overflows a fixed grid cell (the GRID.md gotcha), so each
/// cell uses a compact card (icon + name + subtitle) instead — same data,
/// same tap.
class _LocationsBentoGrid extends StatelessWidget {
  const _LocationsBentoGrid({required this.locations, required this.canEdit});

  final List<Location> locations;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Icon chip + name (2 lines) + a short subtitle, growing with text
        // scale so the 2-up phone cell never clips.
        mainAxisExtent: 132 + 40 * scale,
      ),
      itemCount: locations.length,
      itemBuilder: (context, i) {
        final l = locations[i];
        return _LocationGridCard(
          key: ValueKey('location-${l.id}'),
          location: l,
          canEdit: canEdit,
        );
      },
    );
  }
}

/// The grid-cell form of a location — the same identity + subtitle as
/// [_LocationTile], packed into a compact tappable card so it fits a fixed
/// grid cell (a `ListTile` does not). Same edit tap, gated on [canEdit].
class _LocationGridCard extends StatelessWidget {
  const _LocationGridCard({
    required this.location,
    required this.canEdit,
    super.key,
  });

  final Location location;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isOutdoor = location.isOutdoor == 1;
    final cap = location.capacity;
    final subtitle = [
      if (cap != null) 'cap. $cap',
      if (isOutdoor) 'outdoor',
      if (location.notes != null && location.notes!.isNotEmpty) location.notes!,
    ].join(' · ');
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isOutdoor
                ? scheme.tertiaryContainer
                : scheme.surfaceContainerLow,
            child: Icon(
              isOutdoor ? Icons.park_outlined : Icons.home_work_outlined,
              color: isOutdoor
                  ? scheme.onTertiaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            location.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: canEdit
          ? InkWell(
              onTap: () => unawaited(
                context.push('/settings/locations/${location.id}/edit'),
              ),
              child: content,
            )
          : content,
    );
  }
}

class _LocationTile extends ConsumerWidget {
  const _LocationTile({required this.location, required this.canEdit});

  final Location location;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isOutdoor = location.isOutdoor == 1;
    final cap = location.capacity;
    final subtitle = [
      if (cap != null) 'cap. $cap',
      if (isOutdoor) 'outdoor',
      if (location.notes != null && location.notes!.isNotEmpty) location.notes!,
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isOutdoor
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        child: Icon(
          isOutdoor ? Icons.park_outlined : Icons.home_work_outlined,
          color: isOutdoor
              ? scheme.onTertiaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(location.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: canEdit ? const Icon(Icons.chevron_right) : null,
      onTap: canEdit
          ? () => unawaited(
              context.push('/settings/locations/${location.id}/edit'),
            )
          : null,
    );
  }
}
