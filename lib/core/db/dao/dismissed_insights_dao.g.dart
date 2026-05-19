// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dismissed_insights_dao.dart';

// ignore_for_file: type=lint
mixin _$DismissedInsightsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DismissedInsightsTable get dismissedInsights =>
      attachedDatabase.dismissedInsights;
  DismissedInsightsDaoManager get managers => DismissedInsightsDaoManager(this);
}

class DismissedInsightsDaoManager {
  final _$DismissedInsightsDaoMixin _db;
  DismissedInsightsDaoManager(this._db);
  $$DismissedInsightsTableTableManager get dismissedInsights =>
      $$DismissedInsightsTableTableManager(
        _db.attachedDatabase,
        _db.dismissedInsights,
      );
}
