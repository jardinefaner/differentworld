import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/certifications.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// All certs a member currently holds, sorted by cert key.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final certsForMemberProvider =
    StreamProvider.autoDispose.family<List<MemberCertification>, String>(
  (ref, memberId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.certificationsDao.watchForMember(memberId);
  },
);

/// Every cert in the signed-in user's space. Used by future expiring-
/// soon dashboards; teachers see it but the UI gates edits.
final certsInSpaceProvider =
    StreamProvider<List<MemberCertification>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.certificationsDao.watchInSpace(spaceId: spaceId);
});

/// Helpers on a `List<MemberCertification>` for cap-gating UI:
/// `holds()` (on file at all), `isValid()` (on file AND not expired),
/// and `find()` (return the row). Mirrors the old `isValid()` helper
/// that used to live on the member detail screen, now reading from
/// the dedicated table.
extension MemberCertificationsX on List<MemberCertification> {
  /// On file at all (regardless of expiry).
  bool holds(String certKey) {
    for (final c in this) {
      if (c.certKey == certKey) return true;
    }
    return false;
  }

  /// On file AND not expired (or no expiry set, treated as indefinitely
  /// valid). This is what cap-gating UIs key off of.
  bool isValid(String certKey) {
    final today = _todayDate();
    for (final c in this) {
      if (c.certKey != certKey) continue;
      final iso = c.expiresAt;
      if (iso == null || iso.isEmpty) return true; // no expiry = valid
      final dt = DateTime.tryParse(iso);
      if (dt == null) return true;
      return !dt.isBefore(today);
    }
    return false;
  }

  /// The row for a specific cert key, or null if not held. Used by the
  /// UI to read expiry / notes for an existing cert.
  MemberCertification? find(String certKey) {
    for (final c in this) {
      if (c.certKey == certKey) return c;
    }
    return null;
  }
}

DateTime _todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

class CertActions {
  CertActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  /// Add a cert (creates the row). If one already exists for
  /// (memberId, certKey), the underlying upsert refreshes its expiry
  /// instead of duplicating.
  Future<void> add({
    required String memberId,
    required String certKey,
    String? issuedAt,
    String? expiresAt,
    String? notes,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      throw StateError('No Space — cannot add a cert.');
    }
    final db = await _ref.read(appDatabaseProvider.future);
    await db.certificationsDao.upsert(
      id: _uuid.v4(),
      spaceId: spaceId,
      memberId: memberId,
      certKey: certKey,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      notes: notes,
    );
  }

  /// Update the expiry date for an existing cert on a member. If no
  /// row exists yet, this creates one with no issued_at — the user is
  /// declaring "this cert is on file and expires on X."
  Future<void> setExpiry({
    required String memberId,
    required String certKey,
    DateTime? expiresAt,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    final iso = expiresAt == null
        ? null
        : '${expiresAt.year.toString().padLeft(4, '0')}-'
            '${expiresAt.month.toString().padLeft(2, '0')}-'
            '${expiresAt.day.toString().padLeft(2, '0')}';
    await db.certificationsDao.upsert(
      id: _uuid.v4(),
      spaceId: spaceId,
      memberId: memberId,
      certKey: certKey,
      expiresAt: iso,
    );
    // If the new expiry is in the past, cascade-off the cap the cert
    // gates — mirrors the legacy behavior on the JSONB version.
    if (expiresAt != null && expiresAt.isBefore(_todayDate())) {
      await _cascadeOffGatedCaps(memberId, certKey);
    }
  }

  /// Remove a cert. Also clears any capability flags the cert gated.
  Future<void> remove({
    required String memberId,
    required String certKey,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.certificationsDao.deleteByMemberKey(
      memberId: memberId,
      certKey: certKey,
    );
    await _cascadeOffGatedCaps(memberId, certKey);
  }

  /// Turn off every cap that the named cert governs. Mirrors the
  /// pre-refactor behavior: removing MAT also disables
  /// `canAdministerMedication`. Per the model, the cap is the
  /// permission; the cert is the evidence. Lose the evidence → lose
  /// the permission.
  Future<void> _cascadeOffGatedCaps(String memberId, String certKey) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final member = await db.findMemberById(memberId);
    if (member == null) return;
    var caps = member.caps;
    var changed = false;
    for (final cert in Certifications.all) {
      if (cert.key != certKey) continue;
      for (final gated in cert.gatesCaps) {
        if (caps.getBool(gated)) {
          caps = caps.setting(gated, false);
          changed = true;
        }
      }
    }
    if (!changed) return;
    await db.updateMemberCapabilities(memberId, caps.toJson());
  }
}

final certActionsProvider = Provider<CertActions>(CertActions.new);
