import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// All vehicles in the signed-in user's program, ordered by name.
final vehiclesProvider = StreamProvider<List<Vehicle>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.vehiclesDao.watchInSpace(spaceId);
});

/// Live stream of one vehicle by ID. Auto-disposes; family-keyed.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final vehicleByIdProvider = StreamProvider.autoDispose.family<Vehicle?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.vehiclesDao.watchById(id);
  },
);

/// Full log history for a vehicle, newest first.
// ignore: specify_nonobvious_property_types
final vehicleLogsProvider = StreamProvider.autoDispose
    .family<List<VehicleLog>, String>((ref, vehicleId) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.vehiclesDao.watchLogsFor(vehicleId);
    });

/// The most recent log row for a vehicle. Drives the "currently out
/// with X driver" banner on the detail screen.
// ignore: specify_nonobvious_property_types
final latestVehicleLogProvider = StreamProvider.autoDispose
    .family<VehicleLog?, String>((ref, vehicleId) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.vehiclesDao.watchLatestLogFor(vehicleId);
    });

/// Kind discriminator for `vehicle_logs` rows.
class VehicleLogKind {
  static const String checkout = 'checkout';
  static const String checkin = 'checkin';
}

/// Whether a vehicle is currently out (last log was a checkout) vs in.
extension VehicleStatusX on VehicleLog {
  bool get isCheckout => kind == VehicleLogKind.checkout;
}

/// Pair of a [Vehicle] + its latest log, for surfaces that need
/// "what's the current state of every vehicle" — Today's Quick
/// Actions, the slash-command resolver, etc.
class VehicleWithStatus {
  const VehicleWithStatus({required this.vehicle, this.latestLog});

  final Vehicle vehicle;
  final VehicleLog? latestLog;

  /// True when the latest log is a checkout AND that checkout hasn't
  /// been followed by a check-in. (Today's UI uses this directly.)
  bool get isOut => latestLog?.isCheckout ?? false;

  /// True when [isOut] AND the given member is the one who took it
  /// out. Drives "Return van" on a per-viewer basis.
  bool isOutBy(String? memberId) =>
      isOut && memberId != null && latestLog?.driverMemberId == memberId;
}

/// Snapshot of every vehicle's current status. Combines
/// [vehiclesProvider] with one [latestVehicleLogProvider] per row.
/// Used by surfaces that need to branch behavior on "is this vehicle
/// out, and by whom" — Today's Quick Actions and the `/checkout` /
/// `/checkin` slash commands.
///
/// `autoDispose` to match the sibling per-entity vehicle providers
/// — keeps the inner per-vehicle Drift watch streams from staying
/// alive after every watcher has unmounted.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final fleetStatusProvider = StreamProvider.autoDispose<List<VehicleWithStatus>>(
  (ref) {
    return ref
        .watch(vehiclesProvider)
        .when(
          loading: () => const Stream<List<VehicleWithStatus>>.empty(),
          error: (_, _) => const Stream<List<VehicleWithStatus>>.empty(),
          data: (vehicles) async* {
            if (vehicles.isEmpty) {
              yield const <VehicleWithStatus>[];
              return;
            }
            final db = await ref.watch(appDatabaseProvider.future);
            // Combine each vehicle's latest-log stream into one snapshot
            // emission. Drift's `watchLatestLogFor(...)` emits whenever
            // that vehicle's log table changes; we re-snapshot the whole
            // fleet on any change. Cheap — typical fleet is 1-5 vehicles.
            final perVehicleStreams = vehicles.map((v) {
              return db.vehiclesDao
                  .watchLatestLogFor(v.id)
                  .map((log) => VehicleWithStatus(vehicle: v, latestLog: log));
            }).toList();
            // Manually combine: emit the latest of every per-vehicle
            // stream. rxdart's combineLatest would also work — open-coded
            // here to avoid a transitive dep in this file.
            final latestPerVehicle = <String, VehicleWithStatus>{
              for (final v in vehicles) v.id: VehicleWithStatus(vehicle: v),
            };
            final controller = StreamController<List<VehicleWithStatus>>();
            final subs = <StreamSubscription<VehicleWithStatus>>[];
            for (var i = 0; i < perVehicleStreams.length; i++) {
              final id = vehicles[i].id;
              subs.add(
                perVehicleStreams[i].listen((vws) {
                  latestPerVehicle[id] = vws;
                  controller.add(
                    vehicles
                        .map(
                          (v) =>
                              latestPerVehicle[v.id] ??
                              VehicleWithStatus(vehicle: v),
                        )
                        .toList(growable: false),
                  );
                }),
              );
            }
            ref.onDispose(() async {
              for (final s in subs) {
                await s.cancel();
              }
              await controller.close();
            });
            yield* controller.stream;
          },
        );
  },
);

class VehicleActions {
  VehicleActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  Future<String> create({
    required String name,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? color,
    String? notes,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      throw StateError('No Space — cannot add a vehicle.');
    }
    final db = await _ref.read(appDatabaseProvider.future);
    final id = _uuid.v4();
    await db.vehiclesDao.create(
      id: id,
      spaceId: spaceId,
      name: name,
      make: make,
      model: model,
      year: year,
      licensePlate: licensePlate,
      color: color,
      notes: notes,
    );
    return id;
  }

  Future<void> update({
    required String id,
    String? name,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? color,
    String? notes,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.vehiclesDao.update_(
      id: id,
      name: name,
      make: make,
      model: model,
      year: year,
      licensePlate: licensePlate,
      color: color,
      notes: notes,
    );
  }

  /// Persist the vehicle's `capabilities` JSON (e.g. the per-vehicle guided
  /// photo shot-list — see vehicle_photo_shots.dart `withPhotoShots`).
  Future<void> setCapabilities(String id, String capabilitiesJson) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.vehiclesDao.updateCapabilities(id, capabilitiesJson);
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.vehiclesDao.deleteById(id);
  }
}

final vehicleActionsProvider = Provider<VehicleActions>(VehicleActions.new);

class VehicleLogActions {
  VehicleLogActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  /// Insert a new log row. UI passes the inspection JSON (the FACES
  /// checklist) as `itemsJson`.
  Future<String> log({
    required String vehicleId,
    required String kind, // 'checkout' | 'checkin'
    required String itemsJson,
    int? odometer,
    String? fuelLevel,
    String? notes,
    String? bodyDamageNotes,
    String roster = '[]', // JSON array of boarded subject ids (headcount)
  }) async {
    if (kind != 'checkout' && kind != 'checkin') {
      throw ArgumentError('kind must be checkout or checkin, got $kind');
    }
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    final memberId = viewer.memberId;
    if (spaceId == null || memberId == null) {
      throw StateError('No Space / signed-in Member.');
    }
    final db = await _ref.read(appDatabaseProvider.future);
    final id = _uuid.v4();
    await db.vehiclesDao.createLog(
      id: id,
      spaceId: spaceId,
      vehicleId: vehicleId,
      kind: kind,
      driverMemberId: memberId,
      odometer: odometer,
      fuelLevel: fuelLevel,
      itemsJson: itemsJson,
      notes: notes,
      bodyDamageNotes: bodyDamageNotes,
      roster: roster,
    );
    return id;
  }
}

final vehicleLogActionsProvider = Provider<VehicleLogActions>(
  VehicleLogActions.new,
);
