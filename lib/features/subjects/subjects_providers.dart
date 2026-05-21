import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Stream of Subjects in a specific Group. Family provider keyed by
/// group id. Uses `async*` so the provider stays in `loading` until the
/// DB is ready.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final subjectsInGroupProvider =
    StreamProvider.family<List<Subject>, String>(
  (ref, groupId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.subjectsDao.watchInGroup(groupId);
  },
);

/// Every Subject in the signed-in user's program. Used by space-wide
/// rosters (survey list, future "all kids" surfaces) where the group
/// scoping doesn't apply.
final subjectsInSpaceProvider = StreamProvider<List<Subject>>((ref) async* {
  final spaceId = ref.watch(currentMemberProvider).value?.spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.subjectsDao.watchInSpace(spaceId);
});

/// Single Subject by id. Powers the subject detail screen.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final subjectByIdProvider =
    StreamProvider.autoDispose.family<Subject?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* (db.select(db.subjects)..where((s) => s.id.equals(id)))
        .watchSingleOrNull();
  },
);

/// Attendance history for a subject — recent days, newest first. Used
/// by the subject detail "30-day strip" and any future analytics.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final attendanceHistoryForSubjectProvider =
    StreamProvider.autoDispose.family<List<AttendanceRecord>, String>(
  (ref, subjectId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* (db.select(db.attendanceRecords)
          ..where((a) => a.subjectId.equals(subjectId))
          ..orderBy([(a) => OrderingTerm.desc(a.date)])
          ..limit(60))
        .watch();
  },
);

class SubjectActions {
  SubjectActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> create({
    required String groupId,
    required String firstName,
    required String lastName,
    String? dob,
    String? allergies,
    String? notes,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final spaceId = _ref
        .read(viewerProvider)
        .requireSpaceId(action: 'create a child');
    await db.subjectsDao.create(
      id: _uuid.v4(),
      spaceId: spaceId,
      groupId: groupId,
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      allergies: allergies,
      notes: notes,
    );
  }

  Future<void> update({
    required String id,
    String? firstName,
    String? lastName,
    String? dob,
    String? allergies,
    String? notes,
    String? groupId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.subjectsDao.update_(
      id: id,
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      allergies: allergies,
      notes: notes,
      groupId: groupId,
    );
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.subjectsDao.deleteById(id);
  }
}

final subjectActionsProvider = Provider<SubjectActions>(SubjectActions.new);

/// Read-merge-write mutator for `subjects.capabilities` JSONB.
///
/// Same shape as `SpaceCapActions` / `MemberCapActions`: pulls the
/// latest row, merges one key, writes the encoded blob back. That
/// way concurrent edits to *other* keys (e.g. childcare medical
/// fields vs a hypothetical construction-vertical intake field on
/// the same row) don't clobber each other.
///
/// Used by the health profile editor today; reusable by any future
/// per-vertical intake form that needs to write into the JSONB bag.
class SubjectCapActions {
  SubjectCapActions(this._ref);

  final Ref _ref;

  /// Set or clear a single string-shaped cap. Pass `value: null` or
  /// an empty string to remove the key (keeps the JSONB bag tidy).
  Future<void> setStringCap(
    String subjectId,
    String key,
    String? value,
  ) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final s = await (db.select(db.subjects)
          ..where((row) => row.id.equals(subjectId)))
        .getSingleOrNull();
    if (s == null) return;
    // Empty string = clear, same as null. Stops the JSONB bag from
    // accumulating `"": ""` rows when the form is wiped.
    final normalized = (value == null || value.isEmpty) ? null : value;
    final caps = s.caps.setting(key, normalized);
    await db.subjectsDao.updateCapabilities(subjectId, caps.toJson());
  }

  /// Set a boolean cap. Always writes a literal `true` or `false`
  /// (rather than removing the key when false) so consumers can
  /// `.getBool` with a known default without ambiguity.
  Future<void> setBoolCap({
    required String subjectId,
    required String key,
    required bool value,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final s = await (db.select(db.subjects)
          ..where((row) => row.id.equals(subjectId)))
        .getSingleOrNull();
    if (s == null) return;
    final caps = s.caps.setting(key, value);
    await db.subjectsDao.updateCapabilities(subjectId, caps.toJson());
  }
}

final subjectCapActionsProvider =
    Provider<SubjectCapActions>(SubjectCapActions.new);
