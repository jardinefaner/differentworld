import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Kind discriminator for the `schedule_blocks` table — distinguishes
/// on-site activities from field trips, breaks, and closed days.
class BlockKind {
  static const String onSite = 'on_site';
  static const String fieldTrip = 'field_trip';
  static const String breakBlock = 'break';
  static const String closed = 'closed';
}

/// Wave 155: status discriminator for the `schedule_blocks.status`
/// column. `planned` is the default; `skipped` / `cancelled` are
/// authored after the fact and dim the block on the today view.
class BlockStatus {
  static const String planned = 'planned';
  static const String skipped = 'skipped';
  static const String cancelled = 'cancelled';
}

/// Today's ISO date in the device's local zone — matches the way
/// `schedule_blocks.date` is written. Stored as `YYYY-MM-DD`.
String todayIsoLocal() => todayKey();

/// Convert any DateTime to the local YYYY-MM-DD date string used as
/// `schedule_blocks.date`.
String isoDateLocal(DateTime when) => dateKey(when);

/// Blocks on the given `date` across every cohort in the current
/// space. Drives the staff schedule grid.
// ignore: specify_nonobvious_property_types
final scheduleDayProvider = StreamProvider.autoDispose
    .family<List<ScheduleBlock>, String>((ref, date) async* {
      final viewer = ref.watch(viewerProvider);
      final spaceId = viewer.spaceId;
      final db = await ref.watch(appDatabaseProvider.future);
      if (spaceId == null) {
        yield const <ScheduleBlock>[];
        return;
      }
      yield* db.scheduleDao.watchDay(spaceId: spaceId, date: date);
    });

/// Blocks for one cohort on the given `date`. Drives the family-side
/// schedule strip for a kid's room.
// ignore: specify_nonobvious_property_types
final scheduleDayForGroupProvider = StreamProvider.autoDispose
    .family<List<ScheduleBlock>, ({String groupId, String date})>((
      ref,
      key,
    ) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.scheduleDao.watchDayForGroup(
        groupId: key.groupId,
        date: key.date,
      );
    });

/// One schedule block by id, live. Used by surfaces launched from a block
/// (e.g. the per-child photo turns) that need the block's group/title without
/// re-fetching the whole day.
// ignore: specify_nonobvious_property_types
final scheduleBlockByIdProvider = StreamProvider.autoDispose
    .family<ScheduleBlock?, String>(
      (ref, id) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.scheduleDao.watchById(id);
      },
    );

/// The field-trip logistics row (destination / address / notes) for one
/// block, live. 1:1 with the block (kind = field_trip); null for a trip
/// block whose details haven't been filled in yet. Lets the block run
/// sheet's bento show the trip's "Where" without a second fetch.
// ignore: specify_nonobvious_property_types
final tripLogisticsForBlockProvider = StreamProvider.autoDispose
    .family<TripLogistic?, String>(
      (ref, blockId) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.tripsDao.watchByBlockId(blockId);
      },
    );

/// Blocks the given staff member is leading on the given `date`.
/// Powers the "what I'm leading today" specialist brief.
// ignore: specify_nonobvious_property_types
final scheduleDayForLeadProvider = StreamProvider.autoDispose
    .family<List<ScheduleBlock>, ({String memberId, String date})>((
      ref,
      key,
    ) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.scheduleDao.watchDayForLead(
        memberId: key.memberId,
        date: key.date,
      );
    });

/// Wave 158: events on the given `date` for the current space.
/// Drives the banner above the schedule grid and the
/// `/schedule/events` list.
// ignore: specify_nonobvious_property_types
final eventsForDateProvider = StreamProvider.autoDispose
    .family<List<Event>, String>((ref, date) async* {
      final viewer = ref.watch(viewerProvider);
      final spaceId = viewer.spaceId;
      if (spaceId == null) {
        yield const <Event>[];
        return;
      }
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.eventsDao.watchForDate(spaceId: spaceId, date: date);
    });

/// Discriminator for `events.mode`.
class EventMode {
  static const String overlay = 'overlay';
  static const String replaces = 'replaces';
  static const String closesDay = 'closes_day';
}

class ScheduleActions {
  ScheduleActions(this._ref);
  final Ref _ref;

  /// Author a new block. The caller picks group, start/end, and
  /// optionally an activity / lead / location override. Returns the
  /// new block id.
  Future<String> create({
    required String groupId,
    required DateTime startAt,
    required DateTime endAt,
    String? title,
    String? activityId,
    String? leadMemberId,
    String? locationOverrideId,
    String kind = 'on_site',
    String? notes,
    String? curriculumSessionSlug,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'create a schedule block');
    final db = await _ref.read(appDatabaseProvider.future);
    final date = isoDateLocal(startAt);
    return db.scheduleDao.create(
      spaceId: spaceId,
      groupId: groupId,
      date: date,
      startAt: startAt,
      endAt: endAt,
      title: title,
      activityId: activityId,
      leadMemberId: leadMemberId,
      locationOverrideId: locationOverrideId,
      kind: kind,
      notes: notes,
      curriculumSessionSlug: curriculumSessionSlug,
    );
  }

  /// Wave 166.2 — schedule the same block on multiple dates atomically.
  /// `dates` is the list of YYYY-MM-DD strings to spawn on; the time
  /// of day is taken from `startAt` / `endAt`. Returns the new block
  /// ids. All blocks share a `recurrenceId` so a future "edit series"
  /// flow can re-find them.
  Future<List<String>> createBatch({
    required String groupId,
    required List<DateTime> dates,
    required DateTime startAt,
    required DateTime endAt,
    String? title,
    String? activityId,
    String? leadMemberId,
    String? locationOverrideId,
    String kind = 'on_site',
    String? notes,
    String? curriculumSessionSlug,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'create schedule blocks');
    final db = await _ref.read(appDatabaseProvider.future);
    final templates = <({String date, DateTime startAt, DateTime endAt})>[];
    for (final d in dates) {
      final dayStart = DateTime(
        d.year,
        d.month,
        d.day,
        startAt.hour,
        startAt.minute,
      );
      final dayEnd = DateTime(
        d.year,
        d.month,
        d.day,
        endAt.hour,
        endAt.minute,
      );
      templates.add(
        (date: isoDateLocal(dayStart), startAt: dayStart, endAt: dayEnd),
      );
    }
    return db.scheduleDao.createBatch(
      spaceId: spaceId,
      groupId: groupId,
      templates: templates,
      title: title,
      activityId: activityId,
      leadMemberId: leadMemberId,
      locationOverrideId: locationOverrideId,
      kind: kind,
      notes: notes,
      curriculumSessionSlug: curriculumSessionSlug,
    );
  }

  Future<void> update_({
    required String id,
    String? title,
    String? activityId,
    String? leadMemberId,
    String? locationOverrideId,
    DateTime? startAt,
    DateTime? endAt,
    String? kind,
    String? notes,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.scheduleDao.update_(
      id: id,
      title: title,
      activityId: activityId,
      leadMemberId: leadMemberId,
      locationOverrideId: locationOverrideId,
      startAt: startAt,
      endAt: endAt,
      kind: kind,
      notes: notes,
    );
  }

  Future<void> delete_(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.scheduleDao.delete_(id);
  }

  /// Pat persona — Director sets [substituteMemberId] as today's
  /// cover for [absentMemberId]'s blocks in [groupId]. Returns the
  /// count of blocks affected. Pass `substituteMemberId: null` to
  /// restore the original lead.
  Future<int> coverLeadForDay({
    required String groupId,
    required String date,
    required String absentMemberId,
    required String? substituteMemberId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    return db.scheduleDao.assignDailySubstitute(
      groupId: groupId,
      date: date,
      absentMemberId: absentMemberId,
      substituteMemberId: substituteMemberId,
    );
  }

  /// Wave 155: skip or cancel a block without deleting it. The
  /// today view's skip button calls this with 'skipped'; the edit
  /// sheet exposes 'cancelled' for the director.
  Future<void> setBlockStatus({
    required String id,
    required String status,
    String? reason,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.scheduleDao.setBlockStatus(
      id: id,
      status: status,
      reason: reason,
    );
  }

  /// Wave 157: cross-cohort lead-out. "Pat called out today" — apply
  /// the cover across every cohort she leads in this space on
  /// [date]. Returns the total block count affected so the snackbar
  /// can say "Covered 9 blocks across 3 cohorts."
  Future<int> coverLeadForDayAcrossSpace({
    required String date,
    required String absentMemberId,
    required String? substituteMemberId,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'cover lead');
    final db = await _ref.read(appDatabaseProvider.future);
    return db.scheduleDao.assignDailySubstituteAcrossSpace(
      spaceId: spaceId,
      date: date,
      absentMemberId: absentMemberId,
      substituteMemberId: substituteMemberId,
    );
  }
}

final scheduleActionsProvider = Provider<ScheduleActions>(ScheduleActions.new);

/// Wave 158: create / delete one-off events. Updates aren't wired
/// yet — director's options on a created event are "use as is" or
/// "delete + recreate," which is fine for v1.
class EventActions {
  EventActions(this._ref);
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  Future<String> create({
    required DateTime date,
    required String title,
    String mode = 'overlay',
    List<String> groupIds = const [],
    DateTime? startAt,
    DateTime? endAt,
    String? description,
    String? color,
    String? locationId,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'create an event');
    final db = await _ref.read(appDatabaseProvider.future);
    return db.eventsDao.create(
      id: _uuid.v4(),
      spaceId: spaceId,
      date: dateKey(date),
      title: title,
      mode: mode,
      groupIdsJson: _jsonEncodeList(groupIds),
      startAt: startAt?.toUtc().toIso8601String(),
      endAt: endAt?.toUtc().toIso8601String(),
      description: description,
      color: color,
      locationId: locationId,
      createdBy: viewer.memberId,
    );
  }

  Future<void> delete_(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.eventsDao.delete_(id);
  }

  static String _jsonEncodeList(List<String> items) =>
      '[${items.map((s) => '"$s"').join(',')}]';
}

final eventActionsProvider = Provider<EventActions>(EventActions.new);
