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
  yield* db.watchVehiclesInSpace(spaceId);
});

/// Live stream of one vehicle by ID. Auto-disposes; family-keyed.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final vehicleByIdProvider =
    StreamProvider.autoDispose.family<Vehicle?, String>((ref, id) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.watchVehicle(id);
});

/// Full log history for a vehicle, newest first.
// ignore: specify_nonobvious_property_types
final vehicleLogsProvider = StreamProvider.autoDispose
    .family<List<VehicleLog>, String>((ref, vehicleId) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.watchLogsForVehicle(vehicleId);
});

/// The most recent log row for a vehicle. Drives the "currently out
/// with X driver" banner on the detail screen.
// ignore: specify_nonobvious_property_types
final latestVehicleLogProvider = StreamProvider.autoDispose
    .family<VehicleLog?, String>((ref, vehicleId) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.watchLatestLogForVehicle(vehicleId);
});

/// Whether a vehicle is currently out (last log was a checkout) vs in.
extension VehicleStatusX on VehicleLog {
  bool get isCheckout => kind == 'checkout';
}

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
    await db.createVehicle(
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
    await db.updateVehicle(
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

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.deleteVehicle(id);
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
    await db.createVehicleLog(
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
    );
    return id;
  }
}

final vehicleLogActionsProvider =
    Provider<VehicleLogActions>(VehicleLogActions.new);
