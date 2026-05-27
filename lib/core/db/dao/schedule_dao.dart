import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'schedule_dao.g.dart';

/// The day's plan, per-cohort. Each `ScheduleBlock` is one row of the
/// schedule grid (cohort × time block) carrying an activity, a lead,
/// a location override, and a kind (on_site / field_trip / break /
/// closed). Block boundaries are stored per row — there is no global
/// "block size" anywhere.
@DriftAccessor(tables: [ScheduleBlocks])
class ScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduleDaoMixin {
  ScheduleDao(super.attachedDatabase);

  static const _uuid = Uuid();

  /// Every block on this date, across all cohorts, ordered by start.
  /// Drives the staff-side schedule grid.
  Stream<List<ScheduleBlock>> watchDay({
    required String spaceId,
    required String date,
  }) {
    return (select(scheduleBlocks)
          ..where((b) => b.spaceId.equals(spaceId) & b.date.equals(date))
          ..orderBy([
            (b) => OrderingTerm(expression: b.startAt),
            (b) => OrderingTerm(expression: b.groupId),
          ]))
        .watch();
  }

  /// One cohort's schedule for the date — the row used to render the
  /// family-side per-kid view.
  Stream<List<ScheduleBlock>> watchDayForGroup({
    required String groupId,
    required String date,
  }) {
    return (select(scheduleBlocks)
          ..where((b) => b.groupId.equals(groupId) & b.date.equals(date))
          ..orderBy([(b) => OrderingTerm(expression: b.startAt)]))
        .watch();
  }

  /// The blocks a specific staff member is leading on this date —
  /// powers the "what am I leading today" specialist brief.
  ///
  /// Honours the Pat-persona substitute handoff: a block whose
  /// `lead_substitute_member_id` is set surfaces in the substitute's
  /// card (not the original lead's). The query is essentially
  /// `COALESCE(substitute, lead) = me`:
  ///
  /// * If `substitute IS NULL`, match when `lead = me`.
  /// * If `substitute IS NOT NULL`, match when `substitute = me`.
  ///
  /// This way the absent person's blocks disappear from their own
  /// LeadingTodayCard automatically, and the cover sees them with a
  /// "Covering for …" badge.
  Stream<List<ScheduleBlock>> watchDayForLead({
    required String memberId,
    required String date,
  }) {
    return (select(scheduleBlocks)
          ..where(
            (b) =>
                b.date.equals(date) &
                ((b.leadSubstituteMemberId.isNull() &
                        b.leadMemberId.equals(memberId)) |
                    b.leadSubstituteMemberId.equals(memberId)),
          )
          ..orderBy([(b) => OrderingTerm(expression: b.startAt)]))
        .watch();
  }

  Stream<ScheduleBlock?> watchById(String id) {
    return (select(scheduleBlocks)..where((b) => b.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<String> create({
    required String spaceId,
    required String groupId,
    required String date,
    required DateTime startAt,
    required DateTime endAt,
    String? activityId,
    String? leadMemberId,
    String? locationOverrideId,
    String kind = 'on_site',
    String? notes,
    String? curriculumSessionSlug,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(scheduleBlocks).insert(
      ScheduleBlocksCompanion.insert(
        id: id,
        spaceId: spaceId,
        groupId: groupId,
        date: date,
        startAt: startAt.toUtc().toIso8601String(),
        endAt: endAt.toUtc().toIso8601String(),
        activityId: Value(activityId),
        leadMemberId: Value(leadMemberId),
        locationOverrideId: Value(locationOverrideId),
        kind: kind,
        notes: Value(notes),
        curriculumSessionSlug: Value(curriculumSessionSlug),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> update_({
    required String id,
    String? activityId,
    String? leadMemberId,
    String? locationOverrideId,
    DateTime? startAt,
    DateTime? endAt,
    String? kind,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(scheduleBlocks)..where((b) => b.id.equals(id))).write(
      ScheduleBlocksCompanion(
        activityId:
            activityId == null ? const Value.absent() : Value(activityId),
        leadMemberId: leadMemberId == null
            ? const Value.absent()
            : Value(leadMemberId),
        locationOverrideId: locationOverrideId == null
            ? const Value.absent()
            : Value(locationOverrideId),
        startAt: startAt == null
            ? const Value.absent()
            : Value(startAt.toUtc().toIso8601String()),
        endAt: endAt == null
            ? const Value.absent()
            : Value(endAt.toUtc().toIso8601String()),
        kind: kind == null ? const Value.absent() : Value(kind),
        notes: notes == null ? const Value.absent() : Value(notes),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> delete_(String id) async {
    await (delete(scheduleBlocks)..where((b) => b.id.equals(id))).go();
  }

  /// Pat persona: director-set substitute for one cohort's blocks on
  /// a given date.
  ///
  /// Updates every block matching `(groupId, date)` whose planned
  /// lead is `absentMemberId`, setting `lead_substitute_member_id`
  /// to `substituteMemberId`. Pass `substituteMemberId = null` to
  /// clear the substitute (the absent person reclaims their blocks
  /// — useful for "they're back, undo the cover").
  ///
  /// Returns the number of blocks affected so the UI can confirm
  /// "Covered 6 blocks for Sam today" instead of a silent action.
  ///
  /// Restricting to the absent person's planned blocks (rather than
  /// every block in the group) avoids stepping on co-led blocks
  /// where a different counselor was already the planned lead.
  Future<int> assignDailySubstitute({
    required String groupId,
    required String date,
    required String absentMemberId,
    required String? substituteMemberId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return (update(scheduleBlocks)
          ..where(
            (b) =>
                b.groupId.equals(groupId) &
                b.date.equals(date) &
                b.leadMemberId.equals(absentMemberId),
          ))
        .write(
      ScheduleBlocksCompanion(
        leadSubstituteMemberId: substituteMemberId == null
            ? const Value<String?>(null)
            : Value(substituteMemberId),
        updatedAt: Value(now),
      ),
    );
  }

  /// Wave 155: set the status of a single block. The on-screen
  /// "Skip" button on the today view calls this with 'skipped';
  /// the edit sheet exposes 'cancelled' for the director. Pass
  /// 'planned' to clear the state.
  Future<void> setBlockStatus({
    required String id,
    required String status,
    String? reason,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(scheduleBlocks)..where((b) => b.id.equals(id))).write(
      ScheduleBlocksCompanion(
        status: Value(status),
        statusReason:
            reason == null ? const Value<String?>(null) : Value(reason),
        updatedAt: Value(now),
      ),
    );
  }

  /// Wave 157: cross-cohort lead-out. Same as `assignDailySubstitute`
  /// but covers `absentMemberId`'s planned blocks ANYWHERE in the
  /// space on `date` — useful when the director hears "Pat called out
  /// today" and wants to reassign every one of her blocks to one
  /// cover without flipping into each cohort.
  ///
  /// Scoped on `space_id` rather than `group_id` so a director in a
  /// program with multiple cohorts can reassign in one tap.
  Future<int> assignDailySubstituteAcrossSpace({
    required String spaceId,
    required String date,
    required String absentMemberId,
    required String? substituteMemberId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return (update(scheduleBlocks)
          ..where(
            (b) =>
                b.spaceId.equals(spaceId) &
                b.date.equals(date) &
                b.leadMemberId.equals(absentMemberId),
          ))
        .write(
      ScheduleBlocksCompanion(
        leadSubstituteMemberId: substituteMemberId == null
            ? const Value<String?>(null)
            : Value(substituteMemberId),
        updatedAt: Value(now),
      ),
    );
  }
}
