// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_dao.dart';

// ignore_for_file: type=lint
mixin _$ScheduleDaoMixin on DatabaseAccessor<AppDatabase> {
  $ScheduleBlocksTable get scheduleBlocks => attachedDatabase.scheduleBlocks;
  ScheduleDaoManager get managers => ScheduleDaoManager(this);
}

class ScheduleDaoManager {
  final _$ScheduleDaoMixin _db;
  ScheduleDaoManager(this._db);
  $$ScheduleBlocksTableTableManager get scheduleBlocks =>
      $$ScheduleBlocksTableTableManager(
        _db.attachedDatabase,
        _db.scheduleBlocks,
      );
}
