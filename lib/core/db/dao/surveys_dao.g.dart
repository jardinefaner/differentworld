// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'surveys_dao.dart';

// ignore_for_file: type=lint
mixin _$SurveysDaoMixin on DatabaseAccessor<AppDatabase> {
  $SurveyResponsesTable get surveyResponses => attachedDatabase.surveyResponses;
  SurveysDaoManager get managers => SurveysDaoManager(this);
}

class SurveysDaoManager {
  final _$SurveysDaoMixin _db;
  SurveysDaoManager(this._db);
  $$SurveyResponsesTableTableManager get surveyResponses =>
      $$SurveyResponsesTableTableManager(
        _db.attachedDatabase,
        _db.surveyResponses,
      );
}
