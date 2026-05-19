// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entries_dao.dart';

// ignore_for_file: type=lint
mixin _$EntriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $EntriesTable get entries => attachedDatabase.entries;
  EntriesDaoManager get managers => EntriesDaoManager(this);
}

class EntriesDaoManager {
  final _$EntriesDaoMixin _db;
  EntriesDaoManager(this._db);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db.attachedDatabase, _db.entries);
}
