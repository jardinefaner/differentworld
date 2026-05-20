// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locations_dao.dart';

// ignore_for_file: type=lint
mixin _$LocationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocationsTable get locations => attachedDatabase.locations;
  LocationsDaoManager get managers => LocationsDaoManager(this);
}

class LocationsDaoManager {
  final _$LocationsDaoMixin _db;
  LocationsDaoManager(this._db);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db.attachedDatabase, _db.locations);
}
