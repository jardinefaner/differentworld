import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'trips_dao.g.dart';

/// Field-trip logistics — `trip_logistics` (1:1 with a schedule_block
/// of kind=field_trip), `trip_vehicles` (one row per assigned
/// vehicle), `permission_slips` (one per subject per trip), and
/// `headcounts` (transition checkpoints).
///
/// Grouped into one DAO because they're always operated on together:
/// when you "create a field trip" you typically create the logistics
/// row + assign vehicles + check who has slips on file all from the
/// same screen.
@DriftAccessor(
  tables: [TripLogistics, TripVehicles, PermissionSlips, Headcounts],
)
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(super.attachedDatabase);

  static const _uuid = Uuid();

  // -------- trip_logistics --------------------------------------------------

  Stream<TripLogistic?> watchByBlockId(String scheduleBlockId) {
    return (select(tripLogistics)
          ..where((t) => t.scheduleBlockId.equals(scheduleBlockId)))
        .watchSingleOrNull();
  }

  Stream<TripLogistic?> watchById(String id) {
    return (select(tripLogistics)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<String> createLogistics({
    required String spaceId,
    required String scheduleBlockId,
    required String destination,
    String? destinationAddress,
    DateTime? departureAt,
    DateTime? returnAt,
    bool requiresPermissionSlip = true,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(tripLogistics).insert(
      TripLogisticsCompanion.insert(
        id: id,
        spaceId: spaceId,
        scheduleBlockId: scheduleBlockId,
        destination: destination,
        destinationAddress: Value(destinationAddress),
        departureAt: Value(departureAt?.toUtc().toIso8601String()),
        returnAt: Value(returnAt?.toUtc().toIso8601String()),
        requiresPermissionSlip: requiresPermissionSlip ? 1 : 0,
        notes: Value(notes),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  // -------- trip_vehicles ---------------------------------------------------

  Stream<List<TripVehicle>> watchVehiclesFor(String tripLogisticsId) {
    return (select(tripVehicles)
          ..where((v) => v.tripLogisticsId.equals(tripLogisticsId)))
        .watch();
  }

  Future<String> assignVehicle({
    required String spaceId,
    required String tripLogisticsId,
    required String vehicleId,
    String? driverMemberId,
    List<String> manifest = const [],
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(tripVehicles).insert(
      TripVehiclesCompanion.insert(
        id: id,
        spaceId: spaceId,
        tripLogisticsId: tripLogisticsId,
        vehicleId: vehicleId,
        driverMemberId: Value(driverMemberId),
        manifest: jsonEncode(manifest),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> setManifest({
    required String tripVehicleId,
    required List<String> subjectIds,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(tripVehicles)..where((v) => v.id.equals(tripVehicleId)))
        .write(
      TripVehiclesCompanion(
        manifest: Value(jsonEncode(subjectIds)),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> removeVehicle(String tripVehicleId) async {
    await (delete(tripVehicles)..where((v) => v.id.equals(tripVehicleId))).go();
  }

  // -------- permission_slips ------------------------------------------------

  Stream<List<PermissionSlip>> watchSlipsForTrip(String tripLogisticsId) {
    return (select(permissionSlips)
          ..where((s) => s.tripLogisticsId.equals(tripLogisticsId)))
        .watch();
  }

  /// Did this kid sign for this trip? Returns the slip row if yes, or
  /// null. The UI uses `value != null` to render the green checkmark.
  Stream<PermissionSlip?> watchSlipForSubject({
    required String tripLogisticsId,
    required String subjectId,
  }) {
    return (select(permissionSlips)
          ..where((s) =>
              s.tripLogisticsId.equals(tripLogisticsId) &
              s.subjectId.equals(subjectId)))
        .watchSingleOrNull();
  }

  Future<String> recordSlip({
    required String spaceId,
    required String subjectId,
    required String tripLogisticsId,
    String? signerGuardianId,
    String? signerName,
    String? sourceUrl,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(permissionSlips).insert(
      PermissionSlipsCompanion.insert(
        id: id,
        spaceId: spaceId,
        subjectId: subjectId,
        tripLogisticsId: tripLogisticsId,
        signerGuardianId: Value(signerGuardianId),
        signerName: Value(signerName),
        signedAt: now,
        sourceUrl: Value(sourceUrl),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> revokeSlip(String id) async {
    await (delete(permissionSlips)..where((s) => s.id.equals(id))).go();
  }

  // -------- headcounts ------------------------------------------------------

  Stream<List<Headcount>> watchHeadcountsForBlock(String scheduleBlockId) {
    return (select(headcounts)
          ..where((h) => h.scheduleBlockId.equals(scheduleBlockId))
          ..orderBy([(h) => OrderingTerm(expression: h.takenAt)]))
        .watch();
  }

  Future<String> recordHeadcount({
    required String spaceId,
    required String scheduleBlockId,
    required String checkpointLabel,
    required int count,
    int? expectedCount,
    String? takenByMemberId,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(headcounts).insert(
      HeadcountsCompanion.insert(
        id: id,
        spaceId: spaceId,
        scheduleBlockId: scheduleBlockId,
        checkpointLabel: checkpointLabel,
        count: count,
        expectedCount: Value(expectedCount),
        takenByMemberId: Value(takenByMemberId),
        takenAt: now,
        notes: Value(notes),
        createdAt: now,
      ),
    );
    return id;
  }
}
