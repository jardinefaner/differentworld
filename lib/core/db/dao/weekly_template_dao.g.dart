// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weekly_template_dao.dart';

// ignore_for_file: type=lint
mixin _$WeeklyTemplateDaoMixin on DatabaseAccessor<AppDatabase> {
  $WeeklyTemplatesTable get weeklyTemplates => attachedDatabase.weeklyTemplates;
  $WeeklyTemplateBlocksTable get weeklyTemplateBlocks =>
      attachedDatabase.weeklyTemplateBlocks;
  $ScheduleBlocksTable get scheduleBlocks => attachedDatabase.scheduleBlocks;
  WeeklyTemplateDaoManager get managers => WeeklyTemplateDaoManager(this);
}

class WeeklyTemplateDaoManager {
  final _$WeeklyTemplateDaoMixin _db;
  WeeklyTemplateDaoManager(this._db);
  $$WeeklyTemplatesTableTableManager get weeklyTemplates =>
      $$WeeklyTemplatesTableTableManager(
        _db.attachedDatabase,
        _db.weeklyTemplates,
      );
  $$WeeklyTemplateBlocksTableTableManager get weeklyTemplateBlocks =>
      $$WeeklyTemplateBlocksTableTableManager(
        _db.attachedDatabase,
        _db.weeklyTemplateBlocks,
      );
  $$ScheduleBlocksTableTableManager get scheduleBlocks =>
      $$ScheduleBlocksTableTableManager(
        _db.attachedDatabase,
        _db.scheduleBlocks,
      );
}
