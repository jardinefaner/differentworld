// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trips_dao.dart';

// ignore_for_file: type=lint
mixin _$TripsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TripLogisticsTable get tripLogistics => attachedDatabase.tripLogistics;
  $TripVehiclesTable get tripVehicles => attachedDatabase.tripVehicles;
  $PermissionSlipsTable get permissionSlips => attachedDatabase.permissionSlips;
  $HeadcountsTable get headcounts => attachedDatabase.headcounts;
  TripsDaoManager get managers => TripsDaoManager(this);
}

class TripsDaoManager {
  final _$TripsDaoMixin _db;
  TripsDaoManager(this._db);
  $$TripLogisticsTableTableManager get tripLogistics =>
      $$TripLogisticsTableTableManager(_db.attachedDatabase, _db.tripLogistics);
  $$TripVehiclesTableTableManager get tripVehicles =>
      $$TripVehiclesTableTableManager(_db.attachedDatabase, _db.tripVehicles);
  $$PermissionSlipsTableTableManager get permissionSlips =>
      $$PermissionSlipsTableTableManager(
        _db.attachedDatabase,
        _db.permissionSlips,
      );
  $$HeadcountsTableTableManager get headcounts =>
      $$HeadcountsTableTableManager(_db.attachedDatabase, _db.headcounts);
}
