import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'vehicles_dao.g.dart';

/// Drift mutators for fleet vehicles + their inspection logs.
///
/// Two tables in one DAO because vehicle_logs has no independent
/// reader — every read is keyed to a vehicle.
@DriftAccessor(tables: [Vehicles, VehicleLogs])
class VehiclesDao extends DatabaseAccessor<AppDatabase>
    with _$VehiclesDaoMixin {
  VehiclesDao(super.attachedDatabase);

  // -- Vehicles --

  Stream<List<Vehicle>> watchInSpace(String spaceId) {
    return (select(vehicles)
          ..where((v) => v.spaceId.equals(spaceId))
          ..orderBy([(v) => OrderingTerm(expression: v.name)]))
        .watch();
  }

  Stream<Vehicle?> watchById(String id) {
    return (select(vehicles)..where((v) => v.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Vehicle?> findById(String id) {
    return (select(vehicles)..where((v) => v.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> create({
    required String id,
    required String spaceId,
    required String name,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? color,
    String? notes,
    String capabilitiesJson = '{}',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(vehicles).insert(
      VehiclesCompanion.insert(
        id: id,
        spaceId: spaceId,
        name: name,
        make: Value(make),
        model: Value(model),
        year: Value(year),
        licensePlate: Value(licensePlate),
        color: Value(color),
        notes: Value(notes),
        capabilities: capabilitiesJson,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> update_({
    required String id,
    String? name,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? color,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(vehicles)..where((v) => v.id.equals(id))).write(
      VehiclesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        make: make == null ? const Value.absent() : Value(make),
        model: model == null ? const Value.absent() : Value(model),
        year: year == null ? const Value.absent() : Value(year),
        licensePlate: licensePlate == null
            ? const Value.absent()
            : Value(licensePlate),
        color: color == null ? const Value.absent() : Value(color),
        notes: notes == null ? const Value.absent() : Value(notes),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateCapabilities(String id, String capsJson) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(vehicles)..where((v) => v.id.equals(id))).write(
      VehiclesCompanion(
        capabilities: Value(capsJson),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updatePhotoUrl(String id, String? url) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(vehicles)..where((v) => v.id.equals(id))).write(
      VehiclesCompanion(
        photoUrl: Value(url),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (delete(vehicles)..where((v) => v.id.equals(id))).go();
  }

  // -- Vehicle logs --

  Stream<List<VehicleLog>> watchLogsFor(String vehicleId) {
    return (select(vehicleLogs)
          ..where((l) => l.vehicleId.equals(vehicleId))
          ..orderBy([
            (l) => OrderingTerm(
                  expression: l.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  /// Latest log row for a vehicle. The vehicle's current state is
  /// "out" if this is a checkout, "in" otherwise (or no row → never
  /// driven).
  Stream<VehicleLog?> watchLatestLogFor(String vehicleId) {
    return (select(vehicleLogs)
          ..where((l) => l.vehicleId.equals(vehicleId))
          ..orderBy([
            (l) => OrderingTerm(
                  expression: l.createdAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> createLog({
    required String id,
    required String spaceId,
    required String vehicleId,
    required String kind,
    required String driverMemberId,
    int? odometer,
    String? fuelLevel,
    String itemsJson = '{}',
    String? notes,
    String? bodyDamageNotes,
    String roster = '[]',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(vehicleLogs).insert(
      VehicleLogsCompanion.insert(
        id: id,
        spaceId: spaceId,
        vehicleId: vehicleId,
        kind: kind,
        driverMemberId: driverMemberId,
        odometer: Value(odometer),
        fuelLevel: Value(fuelLevel),
        items: itemsJson,
        notes: Value(notes),
        bodyDamageNotes: Value(bodyDamageNotes),
        // Always set explicitly — a server default is a no-op over PowerSync.
        roster: Value(roster),
        createdAt: now,
      ),
    );
  }
}
