import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// One child on the dismissal board: who they are, their cohort, and —
/// if they've already been released today — the departure entry that
/// records it (null = still here).
class PickupBoardEntry {
  const PickupBoardEntry({
    required this.subject,
    required this.group,
    this.departure,
    this.leftEarly = false,
  });

  final Subject subject;
  final Group group;
  final Entry? departure;

  /// True when the child left via an attendance `early_pickup` status
  /// rather than a board release. They show in the released list (so a
  /// parent arriving never finds the child mysteriously absent from the
  /// board) but carry no departure entry, so there's no Undo.
  final bool leftEarly;

  bool get released => departure != null || leftEarly;
  String get fullName => '${subject.firstName} ${subject.lastName}'.trim();
}

/// The cross-program dismissal board, split into who's still in the
/// building and who's been picked up today.
class PickupBoard {
  const PickupBoard({required this.stillHere, required this.released});

  final List<PickupBoardEntry> stillHere;
  final List<PickupBoardEntry> released;

  int get hereCount => stillHere.length;
  int get releasedCount => released.length;
  bool get isEmpty => stillHere.isEmpty && released.isEmpty;
}

/// Today's departure entries across the space (kind='departure').
final _departuresTodayProvider = StreamProvider<List<Entry>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.entriesDao.watchInSpace(
    spaceId: spaceId,
    kind: EntryKind.departure,
  );
});

/// Pure board assembly — kept out of the provider so it's unit-testable
/// without a database.
///
/// "Here" = a child marked **present** or **late** today (they came and
/// are in the building). A child is **released** when a departure entry
/// exists for them today. Attendance and departure are SEPARATE axes —
/// nothing here reads or writes the attendance status, so releasing a
/// child can never alter the day's "did they attend" record.
///
/// [subjectsByGroup] / [recordsByGroup] are keyed by group id; a group
/// missing from either is skipped (its streams haven't delivered yet).
/// [departures] is the raw space-wide departure list — only rows whose
/// local date equals [today] count, latest-per-subject winning.
PickupBoard computePickupBoard({
  required List<Group> groups,
  required Map<String, List<Subject>> subjectsByGroup,
  required Map<String, List<AttendanceRecord>> recordsByGroup,
  required List<Entry> departures,
  required String today,
}) {
  final departedToday = <String, Entry>{};
  for (final e in departures) {
    final sid = e.subjectId;
    if (sid == null) continue;
    final local = DateTime.tryParse(e.recordedAt)?.toLocal();
    if (local == null || dateKey(local) != today) continue;
    final prev = departedToday[sid];
    if (prev == null || e.recordedAt.compareTo(prev.recordedAt) > 0) {
      departedToday[sid] = e;
    }
  }

  final stillHere = <PickupBoardEntry>[];
  final released = <PickupBoardEntry>[];
  for (final g in groups) {
    final subjects = subjectsByGroup[g.id];
    final records = recordsByGroup[g.id];
    if (subjects == null || records == null) continue;

    final statusBySubject = <String, AttendanceStatus?>{
      for (final r in records) r.subjectId: AttendanceStatus.fromDb(r.status),
    };
    for (final s in subjects) {
      final st = statusBySubject[s.id];
      // Everyone who came today: present / late (in the building) or
      // early_pickup (came, already left early). Absent / excused / no
      // record never appear.
      final came = st == AttendanceStatus.present ||
          st == AttendanceStatus.late ||
          st == AttendanceStatus.earlyPickup;
      if (!came) continue;
      final dep = departedToday[s.id];
      final leftEarly = st == AttendanceStatus.earlyPickup && dep == null;
      if (dep == null && !leftEarly) {
        stillHere.add(PickupBoardEntry(subject: s, group: g));
      } else {
        released.add(
          PickupBoardEntry(
            subject: s,
            group: g,
            departure: dep,
            leftEarly: leftEarly,
          ),
        );
      }
    }
  }

  int byName(PickupBoardEntry a, PickupBoardEntry b) =>
      a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
  // Still-here: cohort, then name (scans like the roster).
  stillHere.sort((a, b) {
    final byGroup =
        a.group.name.toLowerCase().compareTo(b.group.name.toLowerCase());
    return byGroup != 0 ? byGroup : byName(a, b);
  });
  // Released: board releases (with a timestamp) most-recent first, then
  // early-pickups (no departure time) alphabetically at the end.
  released.sort((a, b) {
    final at = a.departure?.recordedAt;
    final bt = b.departure?.recordedAt;
    if (at != null && bt != null) return bt.compareTo(at);
    if (at != null) return -1; // timed releases before early-pickups
    if (bt != null) return 1;
    return byName(a, b);
  });

  return PickupBoard(stillHere: stillHere, released: released);
}

/// The cross-program dismissal board. Composes the viewer's groups ×
/// today's attendance × today's departures via [computePickupBoard].
///
/// Built as a plain [Provider] that watches the per-group family
/// providers in a loop (same shape Today uses for its flag rollup), so
/// it recomputes whenever any cohort's subjects/attendance or the
/// departures stream changes. A group whose streams haven't delivered
/// yet is skipped and fills in on its next emit (progressive, never a
/// whole-board spinner once groups are known).
final pickupBoardProvider = Provider<AsyncValue<PickupBoard>>((ref) {
  final groupsAsync = ref.watch(groupsProvider);
  final departuresAsync = ref.watch(_departuresTodayProvider);

  final groups = groupsAsync.value;
  if (groups == null) {
    return groupsAsync.hasError
        ? AsyncError(groupsAsync.error!, groupsAsync.stackTrace!)
        : const AsyncLoading();
  }

  final today = todayKey();
  final subjectsByGroup = <String, List<Subject>>{};
  final recordsByGroup = <String, List<AttendanceRecord>>{};
  for (final g in groups) {
    final subjects = ref.watch(subjectsInGroupProvider(g.id)).value;
    final records = ref
        .watch(attendanceForDayProvider((groupId: g.id, date: today)))
        .value;
    if (subjects == null || records == null) continue;
    subjectsByGroup[g.id] = subjects;
    recordsByGroup[g.id] = records;
  }

  return AsyncData(
    computePickupBoard(
      groups: groups,
      subjectsByGroup: subjectsByGroup,
      recordsByGroup: recordsByGroup,
      departures: departuresAsync.value ?? const <Entry>[],
      today: today,
    ),
  );
});

/// Records + undoes child releases as `entries.kind='departure'` rows.
class PickupBoardActions {
  PickupBoardActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// Log a release of [subjectId] to [releasedTo] (a person's name). When
  /// the pickup is a known guardian, [guardianId] is stamped into the
  /// entry's details for the audit trail. Optimistic: writes locally and
  /// syncs in the background like every other entry.
  ///
  /// Returns `false` (without writing) when there's no active session —
  /// so the caller can surface "sign-in expired" instead of a release
  /// that silently never happened on a safety-critical screen.
  Future<bool> release({
    required String subjectId,
    required String? groupId,
    required String releasedTo,
    String? guardianId,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    final memberId = viewer.memberId;
    if (spaceId == null || memberId == null) return false;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.create(
      id: _uuid.v4(),
      spaceId: spaceId,
      kind: EntryKind.departure,
      recordedBy: memberId,
      groupId: groupId,
      subjectId: subjectId,
      body: releasedTo.trim().isEmpty ? null : releasedTo.trim(),
      detailsJson: guardianId == null
          ? '{}'
          : jsonEncode(<String, dynamic>{'guardian_id': guardianId}),
    );
    return true;
  }

  /// Undo a release — deletes the departure entry so the child returns to
  /// the still-here list. For the "released the wrong kid / they came
  /// back" misfire.
  Future<void> undo(String departureEntryId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.deleteById(departureEntryId);
  }
}

final pickupBoardActionsProvider =
    Provider<PickupBoardActions>(PickupBoardActions.new);
