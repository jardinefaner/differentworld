import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's ISO date in the device's local zone — matches the way
/// `schedule_blocks.date` is written. Stored as `YYYY-MM-DD`.
String todayIsoLocal() {
  final n = DateTime.now();
  final y = n.year.toString().padLeft(4, '0');
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Convert any DateTime to the local YYYY-MM-DD date string used as
/// `schedule_blocks.date`.
String isoDateLocal(DateTime when) {
  final y = when.year.toString().padLeft(4, '0');
  final m = when.month.toString().padLeft(2, '0');
  final d = when.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

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
    .family<List<ScheduleBlock>, ({String groupId, String date})>(
        (ref, key) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.scheduleDao.watchDayForGroup(
    groupId: key.groupId,
    date: key.date,
  );
});

/// Blocks the given staff member is leading on the given `date`.
/// Powers the "what I'm leading today" specialist brief.
// ignore: specify_nonobvious_property_types
final scheduleDayForLeadProvider = StreamProvider.autoDispose
    .family<List<ScheduleBlock>, ({String memberId, String date})>(
        (ref, key) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.scheduleDao.watchDayForLead(
    memberId: key.memberId,
    date: key.date,
  );
});

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
    String? activityId,
    String? leadMemberId,
    String? locationOverrideId,
    String kind = 'on_site',
    String? notes,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'create a schedule block');
    final db = await _ref.read(appDatabaseProvider.future);
    // Derive the date from the local start time so the index alignment
    // is unambiguous. Stored as YYYY-MM-DD; not derived in SQL because
    // PowerSync's sync rules need a string-equal match.
    final date = isoDateLocal(startAt);
    return db.scheduleDao.create(
      spaceId: spaceId,
      groupId: groupId,
      date: date,
      startAt: startAt,
      endAt: endAt,
      activityId: activityId,
      leadMemberId: leadMemberId,
      locationOverrideId: locationOverrideId,
      kind: kind,
      notes: notes,
    );
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
    final db = await _ref.read(appDatabaseProvider.future);
    await db.scheduleDao.update_(
      id: id,
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
}

final scheduleActionsProvider =
    Provider<ScheduleActions>(ScheduleActions.new);
