// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invites_dao.dart';

// ignore_for_file: type=lint
mixin _$InvitesDaoMixin on DatabaseAccessor<AppDatabase> {
  $InvitesTable get invites => attachedDatabase.invites;
  InvitesDaoManager get managers => InvitesDaoManager(this);
}

class InvitesDaoManager {
  final _$InvitesDaoMixin _db;
  InvitesDaoManager(this._db);
  $$InvitesTableTableManager get invites =>
      $$InvitesTableTableManager(_db.attachedDatabase, _db.invites);
}
