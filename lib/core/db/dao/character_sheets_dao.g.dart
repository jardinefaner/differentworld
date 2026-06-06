// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_sheets_dao.dart';

// ignore_for_file: type=lint
mixin _$CharacterSheetsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CharacterSheetsTable get characterSheets => attachedDatabase.characterSheets;
  CharacterSheetsDaoManager get managers => CharacterSheetsDaoManager(this);
}

class CharacterSheetsDaoManager {
  final _$CharacterSheetsDaoMixin _db;
  CharacterSheetsDaoManager(this._db);
  $$CharacterSheetsTableTableManager get characterSheets =>
      $$CharacterSheetsTableTableManager(
        _db.attachedDatabase,
        _db.characterSheets,
      );
}
