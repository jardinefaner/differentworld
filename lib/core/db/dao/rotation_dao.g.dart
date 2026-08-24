// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rotation_dao.dart';

// ignore_for_file: type=lint
mixin _$RotationDaoMixin on DatabaseAccessor<AppDatabase> {
  $RotationRoundsTable get rotationRounds => attachedDatabase.rotationRounds;
  RotationDaoManager get managers => RotationDaoManager(this);
}

class RotationDaoManager {
  final _$RotationDaoMixin _db;
  RotationDaoManager(this._db);
  $$RotationRoundsTableTableManager get rotationRounds =>
      $$RotationRoundsTableTableManager(
        _db.attachedDatabase,
        _db.rotationRounds,
      );
}
