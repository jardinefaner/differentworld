// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicles_dao.dart';

// ignore_for_file: type=lint
mixin _$VehiclesDaoMixin on DatabaseAccessor<AppDatabase> {
  $VehiclesTable get vehicles => attachedDatabase.vehicles;
  $VehicleLogsTable get vehicleLogs => attachedDatabase.vehicleLogs;
  VehiclesDaoManager get managers => VehiclesDaoManager(this);
}

class VehiclesDaoManager {
  final _$VehiclesDaoMixin _db;
  VehiclesDaoManager(this._db);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db.attachedDatabase, _db.vehicles);
  $$VehicleLogsTableTableManager get vehicleLogs =>
      $$VehicleLogsTableTableManager(_db.attachedDatabase, _db.vehicleLogs);
}
