// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enrollments_dao.dart';

// ignore_for_file: type=lint
mixin _$EnrollmentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TermsTable get terms => attachedDatabase.terms;
  $EnrollmentsTable get enrollments => attachedDatabase.enrollments;
  $SubjectsTable get subjects => attachedDatabase.subjects;
  EnrollmentsDaoManager get managers => EnrollmentsDaoManager(this);
}

class EnrollmentsDaoManager {
  final _$EnrollmentsDaoMixin _db;
  EnrollmentsDaoManager(this._db);
  $$TermsTableTableManager get terms =>
      $$TermsTableTableManager(_db.attachedDatabase, _db.terms);
  $$EnrollmentsTableTableManager get enrollments =>
      $$EnrollmentsTableTableManager(_db.attachedDatabase, _db.enrollments);
  $$SubjectsTableTableManager get subjects =>
      $$SubjectsTableTableManager(_db.attachedDatabase, _db.subjects);
}
