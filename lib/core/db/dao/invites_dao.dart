import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'invites_dao.g.dart';

/// Pending team-member / guardian invites. Acceptance flips a flag on
/// the server (`app.accept_invite()` RPC); revocation hard-deletes.
@DriftAccessor(tables: [Invites])
class InvitesDao extends DatabaseAccessor<AppDatabase> with _$InvitesDaoMixin {
  InvitesDao(super.attachedDatabase);

  /// Watch all un-accepted invites for a space. Expired ones are kept
  /// in the list intentionally — the UI labels them "Expired" so the
  /// director can revoke them. (If we filtered by `expires_at > now()`
  /// here, the predicate would be captured at subscription time and
  /// not re-evaluate as the wall clock moves; rows would stick around
  /// past their expiry until the stream is re-subscribed.)
  Stream<List<Invite>> watchPendingInSpace(String spaceId) {
    return (select(invites)
          ..where(
            (i) => i.spaceId.equals(spaceId) & i.acceptedAt.isNull(),
          )
          ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
        .watch();
  }

  Future<void> create({
    required String id,
    required String spaceId,
    required String role,
    String? email,
    String? code,
    String? createdBy,
    String? expiresAt,
    String? subjectId,
    String capabilitiesJson = '{}',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(invites).insert(
      InvitesCompanion.insert(
        id: id,
        spaceId: spaceId,
        role: role,
        email: email == null ? const Value.absent() : Value(email),
        code: code == null ? const Value.absent() : Value(code),
        subjectId: subjectId == null ? const Value.absent() : Value(subjectId),
        createdBy: createdBy == null ? const Value.absent() : Value(createdBy),
        expiresAt: expiresAt == null ? const Value.absent() : Value(expiresAt),
        capabilities: capabilitiesJson,
        createdAt: now,
      ),
    );
  }

  /// "Revoke" = delete the row. The unique constraint on `code` releases
  /// the code for future reuse; the recipient (if any) won't see it
  /// because their sync stream filters to their own space.
  Future<void> revoke(String id) async {
    await (delete(invites)..where((i) => i.id.equals(id))).go();
  }
}
