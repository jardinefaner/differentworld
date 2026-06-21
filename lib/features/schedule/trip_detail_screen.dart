import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/schedule/widgets/trip_headcount_section.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/trips/:blockId` — Wave 159 MVP.
///
/// Reached from BlockEditScreen when the kid sets `kind = field_trip`.
/// One screen with three sections:
///   1. Logistics: destination, address, departure, return, notes.
///   2. Permission slips: per-kid signed/not-signed list.
///   3. Vehicles: assigned vehicles + drivers (read-only here in v1).
///
/// The full 5-step wizard (assign kids → vehicles → drivers → slips →
/// headcounts) lives on top of this for v2. The MVP gets the data
/// shape solid and surfaces the slip status to the director so they
/// know whether the trip can launch.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({required this.blockId, super.key});

  /// schedule_blocks.id of the parent block. trip_logistics is
  /// 1:1 with the block.
  final String blockId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final _destination = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  TripLogistic? _existing;

  @override
  void dispose() {
    _destination.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _seed(TripLogistic? row) {
    if (_existing?.id == row?.id) return;
    _existing = row;
    _destination.text = row?.destination ?? '';
    _address.text = row?.destinationAddress ?? '';
    _notes.text = row?.notes ?? '';
  }

  Future<void> _save() async {
    final viewer = ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'save trip details');
    final db = await ref.read(appDatabaseProvider.future);
    setState(() => _saving = true);
    try {
      if (_existing == null) {
        await db.tripsDao.createLogistics(
          spaceId: spaceId,
          scheduleBlockId: widget.blockId,
          destination: _destination.text.trim(),
          destinationAddress: _address.text.trim().isEmpty
              ? null
              : _address.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      } else {
        await (db.update(
          db.tripLogistics,
        )..where((t) => t.id.equals(_existing!.id))).write(
          TripLogisticsCompanion(
            destination: Value(_destination.text.trim()),
            destinationAddress: Value(
              _address.text.trim().isEmpty ? null : _address.text.trim(),
            ),
            notes: Value(
              _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ),
            updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Trip details saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(appDatabaseProvider);
    return EdgeScaffold(
      backFallbackRoute: '/schedule',
      body: dbAsync.when(
        loading: () => const LoadingSlot(),
        error: (e, _) => ErrorState(
          title: 'Could not load trip details',
          onRetry: () => ref.invalidate(appDatabaseProvider),
        ),
        data: (db) {
          return StreamBuilder<TripLogistic?>(
            stream: db.tripsDao.watchByBlockId(widget.blockId),
            builder: (context, snap) {
              final row = snap.data;
              _seed(row);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  const ContentHeader(
                    title: 'Trip details',
                    subtitle:
                        'Destination, slips, and vehicles for this field trip.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _destination,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      hintText: 'Pumpkin patch · Aquarium',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Pack lunch · sunscreen · meet at lobby',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save trip details'),
                  ),
                  if (row != null) ...[
                    const SizedBox(height: 24),
                    // Safety first: the headcount roll-call leads the
                    // post-setup sections.
                    TripHeadcountSection(
                      blockId: widget.blockId,
                      groupId: null,
                      destination: row.destination,
                    ),
                    const SizedBox(height: 24),
                    _SlipsSection(tripLogisticsId: row.id),
                    const SizedBox(height: 16),
                    _VehiclesSection(tripLogisticsId: row.id),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SlipsSection extends ConsumerWidget {
  const _SlipsSection({required this.tripLogisticsId});
  final String tripLogisticsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dbAsync = ref.watch(appDatabaseProvider);
    if (dbAsync.value == null) return const SizedBox.shrink();
    final db = dbAsync.value!;
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    return StreamBuilder<List<PermissionSlip>>(
      stream: db.tripsDao.watchSlipsForTrip(tripLogisticsId),
      builder: (context, snap) {
        final slips = snap.data ?? const <PermissionSlip>[];
        final signedIds = {for (final s in slips) s.subjectId};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Permission slips',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${signedIds.length} signed of ${subjects.length} kids in '
              'your roster. Tap a kid to mark their slip received.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final subj in subjects)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  signedIds.contains(subj.id)
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  color: signedIds.contains(subj.id)
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: EntityLink(
                  entity: EntityRef(
                    kind: EntityKind.subject,
                    id: subj.id,
                    label: '${subj.firstName} ${subj.lastName}',
                  ),
                  padded: false,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () async {
                  if (signedIds.contains(subj.id)) return;
                  final viewer = ref.read(viewerProvider);
                  final spaceId = viewer.requireSpaceId(action: 'record slip');
                  await db.tripsDao.recordSlip(
                    spaceId: spaceId,
                    tripLogisticsId: tripLogisticsId,
                    subjectId: subj.id,
                    signerName: 'In-person',
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _VehiclesSection extends ConsumerWidget {
  const _VehiclesSection({required this.tripLogisticsId});
  final String tripLogisticsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dbAsync = ref.watch(appDatabaseProvider);
    if (dbAsync.value == null) return const SizedBox.shrink();
    final db = dbAsync.value!;
    return StreamBuilder<List<TripVehicle>>(
      stream: db.tripsDao.watchVehiclesFor(tripLogisticsId),
      builder: (context, snap) {
        final vehicles = snap.data ?? const <TripVehicle>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vehicles & drivers',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            if (vehicles.isEmpty)
              Text(
                'No vehicles assigned. Assign from the Vehicles screen '
                "once the trip's destination is set.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final v in vehicles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_bus_outlined),
                  title: Text('Vehicle ${v.vehicleId.substring(0, 6)}'),
                  subtitle: Text(
                    v.driverMemberId == null
                        ? 'No driver assigned'
                        : 'Driver: ${v.driverMemberId!.substring(0, 6)}',
                  ),
                ),
          ],
        );
      },
    );
  }
}
