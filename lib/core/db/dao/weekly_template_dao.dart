import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'weekly_template_dao.g.dart';

/// Wave 154: weekly schedule template — director's recurring default
/// per cohort × day-of-week. The `generateBlocks` method materializes
/// `schedule_blocks` rows for a date range so the existing schedule
/// surfaces (today view, family lens) read unchanged.
///
/// Day-of-week encoding: 0 = Monday, 6 = Sunday — matches the
/// generator's `(DateTime.weekday - 1)` math. Time-of-day stored as
/// 'HH:MM' strings (no native TIME on local SQLite).
@DriftAccessor(tables: [WeeklyTemplates, WeeklyTemplateBlocks, ScheduleBlocks])
class WeeklyTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$WeeklyTemplateDaoMixin {
  WeeklyTemplateDao(super.attachedDatabase);

  /// Stream the default template for the space (the first / only
  /// one for v1). Null = director hasn't created one yet.
  Stream<WeeklyTemplate?> watchDefault({required String spaceId}) {
    return (select(weeklyTemplates)
          ..where((t) => t.spaceId.equals(spaceId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Stream every slot for one template, ordered by day-of-week then
  /// start_time so the author UI can group cleanly.
  Stream<List<WeeklyTemplateBlock>> watchSlots({required String templateId}) {
    return (select(weeklyTemplateBlocks)
          ..where((b) => b.templateId.equals(templateId))
          ..orderBy([
            (b) => OrderingTerm(expression: b.dayOfWeek),
            (b) => OrderingTerm(expression: b.startTime),
          ]))
        .watch();
  }

  /// Create the default template for a space. Idempotent at the
  /// call-site level — caller checks watchDefault first.
  Future<String> createTemplate({
    required String spaceId,
    String name = 'Default week',
    String? createdBy,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = const Uuid().v4();
    await into(weeklyTemplates).insert(
      WeeklyTemplatesCompanion.insert(
        id: id,
        spaceId: spaceId,
        name: name,
        createdBy: Value(createdBy),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<String> addSlot({
    required String templateId,
    required String spaceId,
    required String groupId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? activityId,
    String? leadMemberId,
    String? locationOverrideId,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = const Uuid().v4();
    await into(weeklyTemplateBlocks).insert(
      WeeklyTemplateBlocksCompanion.insert(
        id: id,
        templateId: templateId,
        spaceId: spaceId,
        groupId: groupId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        activityId: Value(activityId),
        leadMemberId: Value(leadMemberId),
        locationOverrideId: Value(locationOverrideId),
        notes: Value(notes),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> deleteSlot(String id) async {
    await (delete(weeklyTemplateBlocks)..where((b) => b.id.equals(id))).go();
  }

  /// Re-insert a previously-deleted slot VERBATIM — the undo path for
  /// `deleteWithUndo`. The row keeps its stable client UUID, so
  /// insert-or-replace re-creates the exact row and PowerSync re-syncs it.
  Future<void> restoreSlot(WeeklyTemplateBlock slot) async {
    await into(weeklyTemplateBlocks).insertOnConflictUpdate(slot);
  }

  /// Wave 154: materialize schedule_blocks rows for every (date,
  /// matching template slot) in [fromDate]..[toDate] inclusive.
  ///
  /// Idempotency: this method does NOT clear pre-existing
  /// schedule_blocks in the date range. Generation is additive — if
  /// the director re-runs after editing the template, both the old
  /// and the new blocks land. Caller can wipe-then-regen via
  /// `deleteGeneratedBlocksInRange` first.
  ///
  /// Returns the number of new blocks written.
  Future<int> generateBlocks({
    required String spaceId,
    required String templateId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final slots = await (select(
      weeklyTemplateBlocks,
    )..where((b) => b.templateId.equals(templateId))).get();
    if (slots.isEmpty) return 0;
    final now = DateTime.now().toUtc().toIso8601String();
    const uuid = Uuid();
    var written = 0;
    await transaction(() async {
      for (
        var d = fromDate;
        !d.isAfter(toDate);
        d = d.add(const Duration(days: 1))
      ) {
        final dow = d.weekday - 1; // ISO Mon=1..Sun=7 → 0..6
        final daySlots = slots.where((s) => s.dayOfWeek == dow);
        for (final slot in daySlots) {
          final start = _combineDateAndHHMM(d, slot.startTime);
          final end = _combineDateAndHHMM(d, slot.endTime);
          await into(scheduleBlocks).insert(
            ScheduleBlocksCompanion.insert(
              id: uuid.v4(),
              spaceId: spaceId,
              groupId: slot.groupId,
              date: _isoDate(d),
              startAt: start.toUtc().toIso8601String(),
              endAt: end.toUtc().toIso8601String(),
              activityId: Value(slot.activityId),
              leadMemberId: Value(slot.leadMemberId),
              locationOverrideId: Value(slot.locationOverrideId),
              kind: 'on_site',
              // Explicit 'planned' — withDefault is a no-op over PowerSync.
              status: const Value('planned'),
              notes: Value(slot.notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
          written++;
        }
      }
    });
    return written;
  }

  /// Wipe schedule_blocks in a date range so a re-generation doesn't
  /// duplicate. Director-confirmed — caller surfaces a "Replace
  /// existing X blocks?" dialog before calling.
  Future<int> deleteGeneratedBlocksInRange({
    required String spaceId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final fromIso = _isoDate(fromDate);
    final toIso = _isoDate(toDate);
    return (delete(scheduleBlocks)..where(
          (b) =>
              b.spaceId.equals(spaceId) &
              b.date.isBiggerOrEqualValue(fromIso) &
              b.date.isSmallerOrEqualValue(toIso),
        ))
        .go();
  }
}

DateTime _combineDateAndHHMM(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(day.year, day.month, day.day, h, m);
}

String _isoDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
