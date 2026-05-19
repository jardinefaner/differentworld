// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'certifications_dao.dart';

// ignore_for_file: type=lint
mixin _$CertificationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $MemberCertificationsTable get memberCertifications =>
      attachedDatabase.memberCertifications;
  CertificationsDaoManager get managers => CertificationsDaoManager(this);
}

class CertificationsDaoManager {
  final _$CertificationsDaoMixin _db;
  CertificationsDaoManager(this._db);
  $$MemberCertificationsTableTableManager get memberCertifications =>
      $$MemberCertificationsTableTableManager(
        _db.attachedDatabase,
        _db.memberCertifications,
      );
}
