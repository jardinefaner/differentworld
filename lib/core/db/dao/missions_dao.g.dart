// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'missions_dao.dart';

// ignore_for_file: type=lint
mixin _$MissionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $MissionsTable get missions => attachedDatabase.missions;
  MissionsDaoManager get managers => MissionsDaoManager(this);
}

class MissionsDaoManager {
  final _$MissionsDaoMixin _db;
  MissionsDaoManager(this._db);
  $$MissionsTableTableManager get missions =>
      $$MissionsTableTableManager(_db.attachedDatabase, _db.missions);
}
