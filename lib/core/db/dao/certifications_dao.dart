import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'certifications_dao.g.dart';

/// Member certifications — MAT, CPR, food handler, etc. One row per
/// (member, cert_key) enforced by the server-side UNIQUE index; the
/// upsert here keeps the local view consistent with that contract.
@DriftAccessor(tables: [MemberCertifications])
class CertificationsDao extends DatabaseAccessor<AppDatabase>
    with _$CertificationsDaoMixin {
  CertificationsDao(super.attachedDatabase);

  Stream<List<MemberCertification>> watchForMember(String memberId) {
    return (select(memberCertifications)
          ..where((c) => c.memberId.equals(memberId))
          ..orderBy([(c) => OrderingTerm(expression: c.certKey)]))
        .watch();
  }

  /// Every cert in the space — used by the director-facing
  /// expiring-soon dashboard.
  Stream<List<MemberCertification>> watchInSpace({
    required String spaceId,
  }) {
    return (select(memberCertifications)
          ..where((c) => c.spaceId.equals(spaceId))
          ..orderBy([
            (c) => OrderingTerm(expression: c.expiresAt),
            (c) => OrderingTerm(expression: c.certKey),
          ]))
        .watch();
  }

  Future<MemberCertification?> findForMember({
    required String memberId,
    required String certKey,
  }) {
    return (select(memberCertifications)
          ..where(
            (c) => c.memberId.equals(memberId) & c.certKey.equals(certKey),
          ))
        .getSingleOrNull();
  }

  /// Upsert a cert by (member_id, cert_key). Insert if absent; update
  /// expiresAt / issuedAt / notes / documentUrl otherwise. ID is
  /// generated client-side for new rows so any future document
  /// attachment has a stable path.
  Future<String> upsert({
    required String id,
    required String spaceId,
    required String memberId,
    required String certKey,
    String? issuedAt,
    String? expiresAt,
    String? notes,
    String? documentUrl,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await findForMember(
      memberId: memberId,
      certKey: certKey,
    );
    if (existing == null) {
      await into(memberCertifications).insert(
        MemberCertificationsCompanion.insert(
          id: id,
          spaceId: spaceId,
          memberId: memberId,
          certKey: certKey,
          issuedAt: Value(issuedAt),
          expiresAt: Value(expiresAt),
          notes: Value(notes),
          documentUrl: Value(documentUrl),
          createdAt: now,
          updatedAt: now,
        ),
      );
      return id;
    }
    await (update(memberCertifications)
          ..where((c) => c.id.equals(existing.id)))
        .write(
      MemberCertificationsCompanion(
        issuedAt: Value(issuedAt),
        expiresAt: Value(expiresAt),
        notes: Value(notes),
        documentUrl: Value(documentUrl),
        updatedAt: Value(now),
      ),
    );
    return existing.id;
  }

  Future<void> deleteById(String id) async {
    await (delete(memberCertifications)..where((c) => c.id.equals(id)))
        .go();
  }

  Future<void> deleteByMemberKey({
    required String memberId,
    required String certKey,
  }) async {
    await (delete(memberCertifications)
          ..where(
            (c) => c.memberId.equals(memberId) & c.certKey.equals(certKey),
          ))
        .go();
  }
}
