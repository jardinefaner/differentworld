// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guardians_dao.dart';

// ignore_for_file: type=lint
mixin _$GuardiansDaoMixin on DatabaseAccessor<AppDatabase> {
  $GuardiansTable get guardians => attachedDatabase.guardians;
  $SubjectGuardiansTable get subjectGuardians =>
      attachedDatabase.subjectGuardians;
  $SubjectsTable get subjects => attachedDatabase.subjects;
  GuardiansDaoManager get managers => GuardiansDaoManager(this);
}

class GuardiansDaoManager {
  final _$GuardiansDaoMixin _db;
  GuardiansDaoManager(this._db);
  $$GuardiansTableTableManager get guardians =>
      $$GuardiansTableTableManager(_db.attachedDatabase, _db.guardians);
  $$SubjectGuardiansTableTableManager get subjectGuardians =>
      $$SubjectGuardiansTableTableManager(
        _db.attachedDatabase,
        _db.subjectGuardians,
      );
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db.attachedDatabase, _db.subjects);
}
