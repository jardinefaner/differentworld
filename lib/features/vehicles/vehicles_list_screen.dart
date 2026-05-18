import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
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
    final canEditFleet = viewer.canManageProgram;
    final vehiclesAsync = ref.watch(vehiclesProvider);

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load vehicles',
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
      floatingActionButton: vehiclesAsync.maybeWhen(
        data: (v) => (v.isEmpty || !canEditFleet)
            ? null
            : FloatingActionButton.extended(
                onPressed: () => context.push('/settings/vehicles/new'),
                icon: const Icon(Icons.add),
                label: const Text('Vehicle'),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _VehicleTile extends ConsumerWidget {
  const _VehicleTile({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final latestAsync = ref.watch(latestVehicleLogProvider(vehicle.id));
    final isOut = latestAsync.value?.isCheckout ?? false;

    final subtitleParts = <String>[
      if (vehicle.year != null) vehicle.year!.toString(),
      if (vehicle.make != null && vehicle.make!.isNotEmpty) vehicle.make!,
      if (vehicle.model != null && vehicle.model!.isNotEmpty) vehicle.model!,
      if (vehicle.licensePlate != null && vehicle.licensePlate!.isNotEmpty)
        vehicle.licensePlate!.toUpperCase(),
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleAvatar(
        backgroundColor: isOut
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          isOut
              ? Icons.local_shipping_outlined
              : Icons.directions_bus_outlined,
          color: isOut
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(vehicle.name),
      subtitle: Text(
        subtitleParts.isEmpty ? '—' : subtitleParts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isOut
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Out',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: () =>
          context.push('/settings/vehicles/${vehicle.id}'),
    );
  }
}
