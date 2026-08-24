import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'guardians_dao.g.dart';

/// Family-side identities. A guardian row may exist independently
/// (parent of two siblings → one guardian row, two subject_guardians
/// rows); `userId` is set when the guardian has accepted the family
/// invite and signed in.
@DriftAccessor(tables: [Guardians, SubjectGuardians, Subjects])
class GuardiansDao extends DatabaseAccessor<AppDatabase>
    with _$GuardiansDaoMixin {
  GuardiansDao(super.attachedDatabase);

  /// All guardians attached to a specific subject. Joined via the
  /// subject_guardians link table; primary first, then alphabetical.
  Stream<List<Guardian>> watchForSubject(String subjectId) {
    final query =
        select(guardians).join([
            innerJoin(
              subjectGuardians,
              subjectGuardians.guardianId.equalsExp(guardians.id),
            ),
          ])
          ..where(subjectGuardians.subjectId.equals(subjectId))
          ..orderBy([
            OrderingTerm(
              expression: subjectGuardians.isPrimary,
              mode: OrderingMode.desc,
            ),
            OrderingTerm(expression: guardians.name),
          ]);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(guardians)).toList(),
    );
  }

  /// Add a new guardian and attach them to a subject in one
  /// transaction. Used by the "Add guardian" affordance on subject
  /// detail.
  Future<void> createForSubject({
    required String guardianId,
    required String subjectId,
    required String spaceId,
    required String name,
    String? relationship,
    String? phone,
    String? email,
    bool isPrimary = false,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await into(guardians).insert(
        GuardiansCompanion.insert(
          id: guardianId,
          spaceId: spaceId,
          name: name,
          relationship: relationship == null
              ? const Value.absent()
              : Value(relationship),
          phone: phone == null ? const Value.absent() : Value(phone),
          email: email == null ? const Value.absent() : Value(email),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await into(subjectGuardians).insert(
        SubjectGuardiansCompanion.insert(
          id: const Uuid().v4(),
          subjectId: subjectId,
          guardianId: guardianId,
          spaceId: spaceId,
          isPrimary: Value(isPrimary ? 1 : 0),
          createdAt: now,
        ),
      );
    });
  }

  /// Unlink a guardian from a subject. The guardian row stays — they
  /// might still be attached to a sibling, or future re-add.
  Future<void> unlinkFromSubject({
    required String guardianId,
    required String subjectId,
  }) async {
    await (delete(subjectGuardians)..where(
          (sg) =>
              sg.guardianId.equals(guardianId) & sg.subjectId.equals(subjectId),
        ))
        .go();
  }

  /// Find the guardian row that an authenticated user resolves to.
  /// Returns null when the signed-in user isn't linked to any guardian
  /// — i.e., they're staff or not yet onboarded.
  /// Every subject↔guardian link in a space — the cheap way to answer
  /// "which children have nobody to call", which the day-one readiness
  /// briefing asks for the whole roster at once rather than per child.
  Stream<List<SubjectGuardian>> watchLinksInSpace(String spaceId) {
    return (select(
      subjectGuardians,
    )..where((l) => l.spaceId.equals(spaceId))).watch();
  }

  Stream<Guardian?> watchForUser(String authUserId) {
    return (select(
      guardians,
    )..where((g) => g.userId.equals(authUserId))).watchSingleOrNull();
  }

  /// Subjects this guardian is linked to via subject_guardians. The
  /// family-side lens reads ONLY these subjects.
  Stream<List<Subject>> watchChildrenFor(String guardianId) {
    final query =
        select(subjects).join([
            innerJoin(
              subjectGuardians,
              subjectGuardians.subjectId.equalsExp(subjects.id),
            ),
          ])
          ..where(subjectGuardians.guardianId.equals(guardianId))
          ..orderBy([
            OrderingTerm(expression: subjects.firstName),
            OrderingTerm(expression: subjects.lastName),
          ]);
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(subjects)).toList(),
    );
  }
}
