import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
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
    final m = await db.membersDao.findById(memberId);
    if (m == null) return;
    final caps = m.caps.setting(key, value);
    await db.membersDao.updateCapabilities(memberId, caps.toJson());
  }

  /// Change role AND apply the role's default cap bundle on top of the
  /// existing caps. Both writes go through Drift's transaction so
  /// PowerSync picks them up as a single CRUD batch.
  Future<void> setRole(String memberId, String role) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final m = await db.membersDao.findById(memberId);
    if (m == null) return;
    final mergedCaps =
        m.caps.mergedWith(RoleBundles.defaultsFor(role)).toJson();
    await db.transaction(() async {
      await db.membersDao.updateRole(memberId, role);
      await db.membersDao.updateCapabilities(memberId, mergedCaps);
    });
  }

  // Cert add/remove + expiry moved to CertActions in
  // lib/features/certifications/certifications_providers.dart now that
  // certifications are a first-class entity (UX_DECISIONS §8).
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
    final s = await db.spacesDao.findById(spaceId);
    if (s == null) return;
    final caps = s.caps.setting(key, value);
    await db.spacesDao.updateCapabilities(spaceId, caps.toJson());
  }

  /// Set or clear a string cap on this Space's caps JSONB. Pass
  /// `value: null` to remove the key. Used for non-boolean settings
  /// like the vertical picker (childcare / construction / …) and
  /// the kid-mode unlock PIN.
  Future<void> setStringCap(
    String spaceId,
    String key,
    String? value,
  ) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final s = await db.spacesDao.findById(spaceId);
    if (s == null) return;
    final caps = s.caps.setting(key, value);
    await db.spacesDao.updateCapabilities(spaceId, caps.toJson());
  }
}

final spaceCapActionsProvider =
    Provider<SpaceCapActions>(SpaceCapActions.new);
