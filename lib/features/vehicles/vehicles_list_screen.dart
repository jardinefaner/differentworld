import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:differentworld/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/settings/vehicles` — the fleet list. Directors create/edit;
/// drivers (members with `can_drive`) can tap through to a vehicle
/// detail screen and check it out.
class VehiclesListScreen extends ConsumerWidget {
  const VehiclesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final canEditFleet = viewer.canManageSpace;
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      // Chrome '+' is the consistent "add" affordance — always visible
      // when the viewer can edit, matching locations / activities /
      // team / etc. Empty state has its own CTA too; that's fine, the
      // chrome '+' is the GROUND for the verb.
      actions: [
        // Scan-to-check-out is the backup path for the OS deep link.
        // Every signed-in user gets it — the inspection screen
        // self-gates submit on `canDrive`, so a non-driver can still
        // scan and see the form but can't write a log.
        SecondaryActionButton(
          tooltip: 'Scan vehicle QR',
          icon: Icons.qr_code_scanner_outlined,
          onPressed: () => context.push('/settings/vehicles/scan'),
        ),
        if (canEditFleet)
          PrimaryActionButton(
            tooltip: 'New vehicle',
            icon: Icons.add,
            onPressed: () => context.push('/settings/vehicles/new'),
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
                      onPressed: () => context.push('/settings/vehicles/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add vehicle'),
                    )
                  : null,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: vehicles.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Vehicles',
                    subtitle: 'Pre-trip checks and check-in/check-out',
                  ),
                );
              }
              return _VehicleTile(vehicle: vehicles[i - 1]);
            },
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
    final stateUnknown =
        latestAsync.isLoading && latestAsync.value == null;

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
          isOut
              ? Icons.local_shipping_outlined
              : Icons.directions_bus_outlined,
          color: isOut
              ? scheme.onTertiaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      title: Text(vehicle.name),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      onTap: () =>
          context.push('/settings/vehicles/${vehicle.id}'),
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
