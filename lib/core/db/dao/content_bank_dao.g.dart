// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_bank_dao.dart';

// ignore_for_file: type=lint
mixin _$ContentBankDaoMixin on DatabaseAccessor<AppDatabase> {
  $ContentItemsTable get contentItems => attachedDatabase.contentItems;
  ContentBankDaoManager get managers => ContentBankDaoManager(this);
}

class ContentBankDaoManager {
  final _$ContentBankDaoMixin _db;
  ContentBankDaoManager(this._db);
  $$ContentItemsTableTableManager get contentItems =>
      $$ContentItemsTableTableManager(_db.attachedDatabase, _db.contentItems);
}
