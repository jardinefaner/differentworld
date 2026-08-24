// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_events_dao.dart';

// ignore_for_file: type=lint
mixin _$RoomEventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RoomEventsTable get roomEvents => attachedDatabase.roomEvents;
  RoomEventsDaoManager get managers => RoomEventsDaoManager(this);
}

class RoomEventsDaoManager {
  final _$RoomEventsDaoMixin _db;
  RoomEventsDaoManager(this._db);
  $$RoomEventsTableTableManager get roomEvents =>
      $$RoomEventsTableTableManager(_db.attachedDatabase, _db.roomEvents);
}
