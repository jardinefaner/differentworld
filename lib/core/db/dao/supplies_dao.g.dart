// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplies_dao.dart';

// ignore_for_file: type=lint
mixin _$SuppliesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SuppliesTable get supplies => attachedDatabase.supplies;
  SuppliesDaoManager get managers => SuppliesDaoManager(this);
}

class SuppliesDaoManager {
  final _$SuppliesDaoMixin _db;
  SuppliesDaoManager(this._db);
  $$SuppliesTableTableManager get supplies =>
      $$SuppliesTableTableManager(_db.attachedDatabase, _db.supplies);
}
