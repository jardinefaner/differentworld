// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spaces_dao.dart';

// ignore_for_file: type=lint
mixin _$SpacesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SpacesTable get spaces => attachedDatabase.spaces;
  SpacesDaoManager get managers => SpacesDaoManager(this);
}

class SpacesDaoManager {
  final _$SpacesDaoMixin _db;
  SpacesDaoManager(this._db);
  $$SpacesTableTableManager get spaces =>
      $$SpacesTableTableManager(_db.attachedDatabase, _db.spaces);
}
