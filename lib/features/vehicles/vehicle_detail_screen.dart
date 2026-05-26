import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/vehicles/inspection_checklist.dart';
import 'package:differentworld/features/vehicles/vehicle_qr_pdf.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/route_title.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// `/vehicles/:id` — fleet vehicle detail. Shows current
/// state (in / out + driver), recent log history, and a check-out /
/// check-in button gated on `canDrive`.
class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final canEdit = viewer.canManageSpace;
    final canDrive = viewer.canDrive;
    final vehicleAsync = ref.watch(vehicleByIdProvider(vehicleId));
    final latestAsync = ref.watch(latestVehicleLogProvider(vehicleId));
    final logsAsync = ref.watch(vehicleLogsProvider(vehicleId));

    final isOut = latestAsync.value?.isCheckout ?? false;
    // Wave 113: dynamic tab title — the vehicle's name (e.g. "Big
    // White Van"). Falls back to "Vehicle" for an unknown id.
    final vehicleName = vehicleAsync.value?.name.trim().isNotEmpty == true
        ? vehicleAsync.value!.name
        : 'Vehicle';

    return RouteTitle(
      title: vehicleName,
      child: EdgeScaffold(
      backFallbackRoute: '/vehicles',
      actions: [
        // Primary verb (check out / check in) lives in the top-right
        // pill alongside the other action chrome. The prior
        // FloatingActionButton.extended overlapped the floating
        // omnibox bar on phone + stranded itself in the bottom-right
        // void on desktop. Wave 94 pulls it back into the chrome
        // row so the action vocabulary is uniform with every other
        // screen.
        if (vehicleAsync.value != null && canDrive)
          PrimaryActionButton(
            tooltip: isOut ? 'Check in' : 'Check out',
            icon: isOut
                ? Icons.assignment_turned_in_outlined
                : Icons.key_outlined,
            onPressed: () => context.push(
              '/vehicles/$vehicleId/${isOut ? 'checkin' : 'checkout'}',
            ),
          ),
        if (canEdit && vehicleAsync.value != null)
          SecondaryActionButton(
            tooltip: 'Print check-out QR',
            icon: Icons.qr_code_2_outlined,
            onPressed: () => printVehicleCheckoutQr(
              vehicle: vehicleAsync.value!,
            ),
          ),
        if (canEdit && vehicleAsync.value != null)
          SecondaryActionButton(
            tooltip: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: () =>
                context.push('/vehicles/$vehicleId/edit'),
          ),
        const SyncStatusIndicator(),
      ],
      body: vehicleAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const ErrorState(title: 'Could not load vehicle'),
        data: (v) {
          if (v == null) {
            return const EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'Vehicle not found',
            );
          }
          return ListView(
            // Shell reserves top + bottom chrome.
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              ContentHeader(
                title: v.name,
                subtitle: _subtitleFor(v),
              ),
              _StatusBanner(
                vehicle: v,
                latest: latestAsync.value,
              ),
              if (!canDrive) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Check-out requires the Driver certification. '
                          'Ask a director to add it on your Team profile.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Recent activity', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              logsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (_, _) => Text(
                  'Could not load history.',
                  style: theme.textTheme.bodySmall,
                ),
                data: (logs) {
                  if (logs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No check-outs yet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final log in logs)
                        _LogRow(log: log),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
    );
  }

  String? _subtitleFor(Vehicle v) {
    final parts = <String>[
      if (v.year != null) v.year!.toString(),
      if ((v.make ?? '').isNotEmpty) v.make!,
      if ((v.model ?? '').isNotEmpty) v.model!,
      if ((v.licensePlate ?? '').isNotEmpty) v.licensePlate!.toUpperCase(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _StatusBanner extends ConsumerWidget {
  const _StatusBanner({required this.vehicle, this.latest});

  final Vehicle vehicle;
  final VehicleLog? latest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOut = latest?.isCheckout ?? false;
    final bg = isOut
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isOut
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSurfaceVariant;

    String headline;
    String? sub;
    if (latest == null) {
      headline = 'No check-outs yet';
      sub = 'First trip will start the log.';
    } else if (isOut) {
      headline = 'Out';
      sub = _driverSubtitle(ref, latest!);
    } else {
      headline = 'Available';
      sub = 'Last in at ${_fmt(latest!.createdAt)}';
    }

    final worst = latest == null
        ? null
        : InspectionResults.fromJson(latest!.items).worst;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isOut
                    ? Icons.local_shipping_outlined
                    : Icons.directions_bus_outlined,
                color: fg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: theme.textTheme.titleMedium?.copyWith(color: fg),
                ),
              ),
              if (worst != null && worst != InspectionStatus.ok)
                _IssueChip(status: worst),
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
          ],
        ],
      ),
    );
  }

  String? _driverSubtitle(WidgetRef ref, VehicleLog log) {
    final memberAsync = ref.watch(memberByIdProvider(log.driverMemberId));
    final m = memberAsync.value;
    final when = _fmt(log.createdAt);
    if (m == null) return 'Out since $when';
    return 'With ${m.displayName} since $when';
  }

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat.MMMd().add_jm().format(dt.toLocal());
  }
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({required this.status});

  final InspectionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnsafe = status == InspectionStatus.unsafe;
    final color =
        isUnsafe ? theme.colorScheme.error : theme.colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isUnsafe ? 'Unsafe' : 'Needs repair',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
        ),
      ),
    );
  }
}

class _LogRow extends ConsumerWidget {
  const _LogRow({required this.log});

  final VehicleLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final memberAsync = ref.watch(memberByIdProvider(log.driverMemberId));
    final driverName = memberAsync.value?.displayName ?? 'Driver';
    final dt = DateTime.tryParse(log.createdAt);
    final when = dt == null
        ? log.createdAt
        : DateFormat.MMMd().add_jm().format(dt.toLocal());
    final isCheckout = log.kind == VehicleLogKind.checkout;
    final worst = InspectionResults.fromJson(log.items).worst;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        isCheckout ? Icons.key_outlined : Icons.assignment_turned_in_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        '${isCheckout ? 'Checked out' : 'Checked in'} · $driverName',
      ),
      subtitle: Text(
        [
          when,
          if (log.odometer != null) '${log.odometer} mi',
          if (log.fuelLevel != null && log.fuelLevel!.isNotEmpty)
            'Fuel ${log.fuelLevel}',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: worst != null && worst != InspectionStatus.ok
          ? _IssueChip(status: worst)
          : null,
    );
  }
}
