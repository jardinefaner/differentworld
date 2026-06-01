// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_supplies_dao.dart';

// ignore_for_file: type=lint
mixin _$ActivitySuppliesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ActivitySuppliesTable get activitySupplies =>
      attachedDatabase.activitySupplies;
  ActivitySuppliesDaoManager get managers => ActivitySuppliesDaoManager(this);
}

class ActivitySuppliesDaoManager {
  final _$ActivitySuppliesDaoMixin _db;
  ActivitySuppliesDaoManager(this._db);
  $$ActivitySuppliesTableTableManager get activitySupplies =>
      $$ActivitySuppliesTableTableManager(
        _db.attachedDatabase,
        _db.activitySupplies,
      );
}
