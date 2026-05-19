// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exports_dao.dart';

// ignore_for_file: type=lint
mixin _$ExportsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExportsTable get exports => attachedDatabase.exports;
  $ExportRecipientsTable get exportRecipients =>
      attachedDatabase.exportRecipients;
  ExportsDaoManager get managers => ExportsDaoManager(this);
}

class ExportsDaoManager {
  final _$ExportsDaoMixin _db;
  ExportsDaoManager(this._db);
  $$ExportsTableTableManager get exports =>
      $$ExportsTableTableManager(_db.attachedDatabase, _db.exports);
  $$ExportRecipientsTableTableManager get exportRecipients =>
      $$ExportRecipientsTableTableManager(
        _db.attachedDatabase,
        _db.exportRecipients,
      );
}
