import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_grid.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:differentworld/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/vehicles` — the fleet list. Directors create/edit;
/// drivers (members with `can_drive`) can tap through to a vehicle
/// detail screen and check it out.
class VehiclesListScreen extends ConsumerWidget {
  const VehiclesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final canEditFleet = viewer.canManageSpace;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the fleet re-lays as a denser 2-up
    // phone card grid (compact vertical tiles) over the SAME provider data;
    // off keeps the existing ResponsiveGrid (single-column phone, 2–3 up on
    // wider screens). Loading / empty / error are identical between the two.
    final bento = bentoEnabled(ref, perScreen: null);

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      // Chrome '+' is the consistent "add" affordance — always visible
      // when the viewer can edit, matching locations / activities /
      // team / etc. Empty state has its own CTA too; that's fine, the
      // chrome '+' is the GROUND for the verb.
      actions: [
        // Scan-to-check-out is the backup path for the OS deep link —
        // mobile-only, since QR scanning needs a camera (no usable
        // scanner on web/desktop; docs/PLATFORM_RUBRIC.md, P1). The
        // inspection screen self-gates submit on `canDrive`, so a
        // non-driver can still scan + see the form but can't write a log.
        if (isMobileCapturePlatform)
          SecondaryActionButton(
            tooltip: 'Scan vehicle QR',
            icon: Icons.qr_code_scanner_outlined,
            onPressed: () => context.push('/vehicles/scan'),
          ),
        if (canEditFleet)
          PrimaryActionButton(
            tooltip: 'New vehicle',
            icon: Icons.add,
            onPressed: () => context.push('/vehicles/new'),
          ),
      ],
      body: vehiclesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load vehicles',
          onRetry: () => ref.invalidate(vehiclesProvider),
        ),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return EmptyState(
              icon: Icons.directions_bus_outlined,
              title: 'No vehicles yet',
              message: canEditFleet
                  ? 'Add a vehicle so drivers can run pre-trip safety '
                        'checks and check it in or out.'
                  : 'Your director will set up the fleet here.',
              action: canEditFleet
                  ? FilledButton.icon(
                      onPressed: () => context.push('/vehicles/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add vehicle'),
                    )
                  : null,
            );
          }
          // Wave 110: ResponsiveGrid so a fleet of vehicles renders
          // as 2 cards/row at tablet, 3 cards/row at desktop. Phone
          // stays single-column. The ContentHeader becomes a sibling
          // ABOVE the grid (it doesn't belong inside the grid
          // because it isn't a card).
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: ContentHeader(
                  title: 'Vehicles',
                  subtitle: 'Pre-trip checks and check-in/check-out',
                ),
              ),
              Expanded(
                child: bento
                    // Bento sweep: a denser max-extent grid — 2-up on a phone
                    // for the compact vertical tiles, more across wider
                    // screens. A lazy `GridView.builder` (the fleet can grow),
                    // so it virtualizes; ContentHeader stays the sibling above.
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 180,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              // Compact tile: icon row + name + chips + status.
                              // A fixed cell that fits all four at the narrow
                              // phone width without overflow.
                              mainAxisExtent: 156,
                            ),
                        itemCount: vehicles.length,
                        itemBuilder: (_, i) => _VehicleGridCard(
                          key: ValueKey('vehicle-card-${vehicles[i].id}'),
                          vehicle: vehicles[i],
                        ),
                      )
                    : ResponsiveGrid(
                        itemCount: vehicles.length,
                        // Vehicle tiles are tall (photo + name + status +
                        // driver row). Adjust aspect so they don't squash.
                        aspectRatio: 1.4,
                        itemBuilder: (_, i) =>
                            _VehicleTile(vehicle: vehicles[i]),
                      ),
              ),
            ],
          );
        },
      ),
      // FAB removed — "New vehicle" lives in the top-right primary
      // action pill above.
    );
  }
}

class _VehicleTile extends ConsumerWidget {
  const _VehicleTile({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final latestAsync = ref.watch(latestVehicleLogProvider(vehicle.id));
    final isOut = latestAsync.value?.isCheckout ?? false;
    final stateUnknown = latestAsync.isLoading && latestAsync.value == null;

    // Subtitle as compact chips — year / make / model / plate. The
    // plate gets its own chip so a driver eyeballing for "TX-1234"
    // finds it without parsing a dot-separated sentence.
    final chips = <Widget>[
      if (vehicle.year != null) _MetaChip(label: vehicle.year!.toString()),
      if (vehicle.make != null && vehicle.make!.isNotEmpty)
        _MetaChip(label: vehicle.make!),
      if (vehicle.model != null && vehicle.model!.isNotEmpty)
        _MetaChip(label: vehicle.model!),
      if (vehicle.licensePlate != null && vehicle.licensePlate!.isNotEmpty)
        _MetaChip(label: vehicle.licensePlate!.toUpperCase(), emphasis: true),
    ];

    return ListTile(
      isThreeLine: chips.isNotEmpty,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isOut
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        child: Icon(
          isOut ? Icons.local_shipping_outlined : Icons.directions_bus_outlined,
          color: isOut ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
        ),
      ),
      title: EntityLink(
        entity: EntityRef(
          kind: EntityKind.vehicle,
          id: vehicle.id,
          label: vehicle.name,
        ),
        padded: false,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: chips.isEmpty
          ? const Text('—')
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 4, runSpacing: 4, children: chips),
            ),
      trailing: stateUnknown
          ? const SkeletonShimmer(
              child: SkeletonBox(width: 36, height: 22, radius: 11),
            )
          : isOut
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Out',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => context.push('/vehicles/${vehicle.id}'),
    );
  }
}

/// The bento-grid variant of [_VehicleTile] — the SAME provider read, chips,
/// and tap, re-laid as a compact vertical card so the fleet tiles 2-up on a
/// phone. `mainAxisSize.min` keeps the column inside the cell's fixed extent;
/// the name clamps to one line and only the first two chips show (a 2-up phone
/// cell can't hold four without wrapping past the floor).
class _VehicleGridCard extends ConsumerWidget {
  const _VehicleGridCard({required this.vehicle, super.key});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final latestAsync = ref.watch(latestVehicleLogProvider(vehicle.id));
    final isOut = latestAsync.value?.isCheckout ?? false;
    final stateUnknown = latestAsync.isLoading && latestAsync.value == null;

    final chips = <Widget>[
      if (vehicle.year != null) _MetaChip(label: vehicle.year!.toString()),
      if (vehicle.make != null && vehicle.make!.isNotEmpty)
        _MetaChip(label: vehicle.make!),
      if (vehicle.model != null && vehicle.model!.isNotEmpty)
        _MetaChip(label: vehicle.model!),
      if (vehicle.licensePlate != null && vehicle.licensePlate!.isNotEmpty)
        _MetaChip(label: vehicle.licensePlate!.toUpperCase(), emphasis: true),
    ];

    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/vehicles/${vehicle.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isOut
                        ? scheme.tertiaryContainer
                        : scheme.surfaceContainerHigh,
                    child: Icon(
                      isOut
                          ? Icons.local_shipping_outlined
                          : Icons.directions_bus_outlined,
                      size: 18,
                      color: isOut
                          ? scheme.onTertiaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  // Status badge mirrors the list row's trailing — Out pill,
                  // skeleton while the latest log is still loading, nothing
                  // when checked in (absence is the "in" cue).
                  if (stateUnknown)
                    const SkeletonShimmer(
                      child: SkeletonBox(width: 30, height: 20, radius: 10),
                    )
                  else if (isOut)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Out',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              EntityLink(
                entity: EntityRef(
                  kind: EntityKind.vehicle,
                  id: vehicle.id,
                  label: vehicle.name,
                ),
                padded: false,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 6),
                // Cap at two chips so the cluster never wraps past the cell's
                // fixed floor at the narrow phone width; the plate (emphasis)
                // is sorted last in the source list so a normal year/make pair
                // shows first.
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: chips.take(2).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.emphasis = false});

  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasis
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: emphasis ? scheme.onPrimaryContainer : scheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: emphasis ? FontWeight.w700 : null,
        ),
      ),
    );
  }
}
