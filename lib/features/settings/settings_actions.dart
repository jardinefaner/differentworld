import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/certifications.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auto-saving mutators for the per-member detail screen.
///
/// Per `docs/UX_DECISIONS.md §1`, capability toggles auto-save on
/// `onChanged`. There is no draft state to flush; each method reads
/// the latest row from the DB before merging the single change, so
/// concurrent edits to *other* cap keys aren't clobbered.
class MemberCapActions {
  MemberCapActions(this._ref);

  final Ref _ref;

  /// Flip one boolean capability on this member's caps blob.
  // Mirrors `Capabilities.setting(key, value)` shape; named param would
  // be a needless detour for one-arg switch handlers.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setCap(String memberId, String key, bool value) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final m = await db.findMemberById(memberId);
    if (m == null) return;
    final caps = m.caps.setting(key, value);
    await db.updateMemberCapabilities(memberId, caps.toJson());
  }

  /// Change role AND apply the role's default cap bundle on top of the
  /// existing caps. Both writes go through Drift's transaction so
  /// PowerSync picks them up as a single CRUD batch.
  Future<void> setRole(String memberId, String role) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final m = await db.findMemberById(memberId);
    if (m == null) return;
    final mergedCaps =
        m.caps.mergedWith(RoleBundles.defaultsFor(role)).toJson();
    await db.transaction(() async {
      await db.updateMemberRole(memberId, role);
      await db.updateMemberCapabilities(memberId, mergedCaps);
    });
  }

  /// Add or remove a certification. When removing, cascade-off any
  /// caps that the cert gates (e.g. MAT gates `canAdministerMedication`)
  /// and drop the matching expiry entry.
  // `add` is positional to mirror the chip-style switch onChanged signature
  // — named would just add ceremony at every call site.
  Future<void> toggleCert(
    String memberId,
    String certKey,
    // Positional to mirror the chip onChanged signature.
    // ignore: avoid_positional_boolean_parameters
    bool add,
  ) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final m = await db.findMemberById(memberId);
    if (m == null) return;
    final base = m.caps;
    final existing = base.getStringList(MemberCaps.certifications);
    final next = {...existing};
    if (add) {
      next.add(certKey);
    } else {
      next.remove(certKey);
    }
    var updated = base.setting(MemberCaps.certifications, next.toList());
    if (!add) {
      for (final cert in Certifications.all) {
        if (cert.key != certKey) continue;
        for (final gated in cert.gatesCaps) {
          updated = updated.setting(gated, false);
        }
      }
      final expiries = Map<String, String>.from(
        base.getStringMap(MemberCaps.certificationExpirations),
      )..remove(certKey);
      updated = updated.setting(
        MemberCaps.certificationExpirations,
        expiries,
      );
    }
    await db.updateMemberCapabilities(memberId, updated.toJson());
  }

  /// Set or clear the expiry date for a specific cert. If the new
  /// expiry is in the past, cascade-off the caps it gates.
  Future<void> setCertExpiry(
    String memberId,
    String certKey,
    DateTime? date,
  ) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final m = await db.findMemberById(memberId);
    if (m == null) return;
    final base = m.caps;
    final expiries = Map<String, String>.from(
      base.getStringMap(MemberCaps.certificationExpirations),
    );
    if (date == null) {
      expiries.remove(certKey);
    } else {
      expiries[certKey] = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }
    var updated = base.setting(
      MemberCaps.certificationExpirations,
      expiries,
    );
    final today = _todayDate();
    if (date != null && date.isBefore(today)) {
      for (final cert in Certifications.all) {
        if (cert.key != certKey) continue;
        for (final gated in cert.gatesCaps) {
          updated = updated.setting(gated, false);
        }
      }
    }
    await db.updateMemberCapabilities(memberId, updated.toJson());
  }

  DateTime _todayDate() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}

final memberCapActionsProvider =
    Provider<MemberCapActions>(MemberCapActions.new);

/// Auto-saving mutator for the program-settings screen.
/// Same model as [MemberCapActions]: each toggle is one read-merge-write
/// against the latest Space row.
class SpaceCapActions {
  SpaceCapActions(this._ref);

  final Ref _ref;

  // Mirrors `Capabilities.setting(key, value)`; named would be ceremony.
  // ignore: avoid_positional_boolean_parameters
  Future<void> setCap(String spaceId, String key, bool value) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final s = await db.findSpaceById(spaceId);
    if (s == null) return;
    final caps = s.caps.setting(key, value);
    await db.updateSpaceCapabilities(spaceId, caps.toJson());
  }
}

final spaceCapActionsProvider =
    Provider<SpaceCapActions>(SpaceCapActions.new);
