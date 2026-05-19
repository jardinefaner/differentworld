// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'captures_dao.dart';

// ignore_for_file: type=lint
mixin _$CapturesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CapturesTable get captures => attachedDatabase.captures;
  CapturesDaoManager get managers => CapturesDaoManager(this);
}

class CapturesDaoManager {
  final _$CapturesDaoMixin _db;
  CapturesDaoManager(this._db);
  $$CapturesTableTableManager get captures =>
      $$CapturesTableTableManager(_db.attachedDatabase, _db.captures);
}
