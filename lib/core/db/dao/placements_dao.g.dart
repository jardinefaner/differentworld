// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'placements_dao.dart';

// ignore_for_file: type=lint
mixin _$PlacementsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TermsTable get terms => attachedDatabase.terms;
  $PlacementsTable get placements => attachedDatabase.placements;
  $SubjectsTable get subjects => attachedDatabase.subjects;
  PlacementsDaoManager get managers => PlacementsDaoManager(this);
}

class PlacementsDaoManager {
  final _$PlacementsDaoMixin _db;
  PlacementsDaoManager(this._db);
  $$TermsTableTableManager get terms =>
      $$TermsTableTableManager(_db.attachedDatabase, _db.terms);
  $$PlacementsTableTableManager get placements =>
      $$PlacementsTableTableManager(_db.attachedDatabase, _db.placements);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db.attachedDatabase, _db.subjects);
}
