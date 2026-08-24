import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'subjects_dao.g.dart';

/// Children. Per-group + per-space readers, plus the photo + caps
/// JSONB write helpers that used to live in the cross-cutting caps
/// section.
@DriftAccessor(tables: [Subjects])
class SubjectsDao extends DatabaseAccessor<AppDatabase>
    with _$SubjectsDaoMixin {
  SubjectsDao(super.attachedDatabase);

  /// A room's CURRENT children. Alumni are excluded here rather than at
  /// each call site — every daily surface (attendance, the pickers, the
  /// arrangement engine) reads through this, and a rollover has to actually
  /// clear the room or it hasn't done anything (docs/ROLLOVER.md).
  Stream<List<Subject>> watchInGroup(String groupId) {
    return (select(subjects)
          ..where(
            (s) => s.groupId.equals(groupId) & s.status.equals('enrolled'),
          )
          ..orderBy([
            (s) => OrderingTerm(expression: s.firstName),
            (s) => OrderingTerm(expression: s.lastName),
          ]))
        .watch();
  }

  /// Every ENROLLED Subject in a space, ordered by name. Used by space-wide
  /// surfaces (survey list, rosters). Alumni are reached deliberately via
  /// [watchAlumniInSpace], never by accident.
  Stream<List<Subject>> watchInSpace(String spaceId) {
    return (select(subjects)
          ..where(
            (s) => s.spaceId.equals(spaceId) & s.status.equals('enrolled'),
          )
          ..orderBy([
            (s) => OrderingTerm(expression: s.firstName),
            (s) => OrderingTerm(expression: s.lastName),
          ]))
        .watch();
  }

  /// Past children, most recently updated first. They keep every record
  /// they ever had; this is the door back to it.
  Stream<List<Subject>> watchAlumniInSpace(String spaceId) {
    return (select(subjects)
          ..where((s) => s.spaceId.equals(spaceId) & s.status.equals('alumni'))
          ..orderBy([
            (s) => OrderingTerm(expression: s.firstName),
            (s) => OrderingTerm(expression: s.lastName),
          ]))
        .watch();
  }

  /// One-shot fetch of a subject row by ID. Use this — not a cached
  /// widget prop — when a write needs the latest `capabilities` to
  /// avoid clobbering concurrent edits to other cap keys.
  Future<Subject?> findById(String id) {
    return (select(subjects)..where((s) => s.id.equals(id))).getSingleOrNull();
  }

  Future<void> create({
    required String id,
    required String spaceId,
    required String groupId,
    required String firstName,
    required String lastName,
    String? dob,
    String? allergies,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(subjects).insert(
      SubjectsCompanion.insert(
        id: id,
        spaceId: spaceId,
        groupId: Value(groupId),
        firstName: firstName,
        lastName: lastName,
        dob: Value(dob),
        allergies: Value(allergies),
        notes: Value(notes),
        capabilities: '{}',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> update_({
    required String id,
    String? firstName,
    String? lastName,
    String? dob,
    String? allergies,
    String? notes,
    String? groupId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(subjects)..where((s) => s.id.equals(id))).write(
      SubjectsCompanion(
        firstName: firstName == null ? const Value.absent() : Value(firstName),
        lastName: lastName == null ? const Value.absent() : Value(lastName),
        dob: dob == null ? const Value.absent() : Value(dob),
        allergies: allergies == null ? const Value.absent() : Value(allergies),
        notes: notes == null ? const Value.absent() : Value(notes),
        groupId: groupId == null ? const Value.absent() : Value(groupId),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (delete(subjects)..where((s) => s.id.equals(id))).go();
  }

  /// Set or clear the subject's photo_url. Pass null to remove (the
  /// underlying Storage object stays — orphans are cheaper than
  /// risking a delete on a still-referenced path).
  Future<void> updatePhotoUrl(String id, String? url) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(subjects)..where((s) => s.id.equals(id))).write(
      SubjectsCompanion(
        photoUrl: Value(url),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateCapabilities(String id, String capabilitiesJson) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(subjects)..where((s) => s.id.equals(id))).write(
      SubjectsCompanion(
        capabilities: Value(capabilitiesJson),
        updatedAt: Value(now),
      ),
    );
  }
}
