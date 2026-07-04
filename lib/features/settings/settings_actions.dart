import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
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
  ///
  /// The bundle is per-vertical — a "manager" in hospitality has a
  /// different default cap set than a "lead_teacher" in childcare.
  /// Vertical comes from the active `verticalLabelsProvider` (which
  /// reads it off the Space's caps); falls back to childcare if the
  /// space row hasn't synced yet.
  Future<void> setRole(String memberId, String role) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final m = await db.membersDao.findById(memberId);
    if (m == null) return;
    final vertical = _ref.read(verticalLabelsProvider).vertical;
    final mergedCaps = m.caps
        .mergedWith(RoleBundles.defaultsFor(role, vertical: vertical))
        .toJson();
    await db.transaction(() async {
      await db.membersDao.updateRole(memberId, role);
      await db.membersDao.updateCapabilities(memberId, mergedCaps);
    });
  }

  /// Set the specialty for `role: specialist` members
  /// (afterschool 4-12 — coach / tutor / health_aide / etc.). Stored
  /// on `member.capabilities.specialty`. Pass null to clear.
  ///
  /// Idempotent: writes through the same `caps.setting()` shape as
  /// boolean caps; `Capabilities` is a JSONB-backed bag and accepts
  /// any `Object?` value.
  Future<void> setSpecialty(String memberId, String? specialty) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final m = await db.membersDao.findById(memberId);
    if (m == null) return;
    final caps = m.caps.setting(ChildcareCaps.specialty, specialty);
    await db.membersDao.updateCapabilities(memberId, caps.toJson());
  }

  /// Set the member's self-authored archetype (docs/IDENTITY_SYSTEM.md §2).
  /// A string cap that decorates, never gates. Pass null to clear. Same
  /// read-merge-write shape as [setSpecialty]. Self-authored — the UI only
  /// offers this on the viewer's OWN profile.
  Future<void> setArchetype(String memberId, String? archetypeId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final m = await db.membersDao.findById(memberId);
    if (m == null) return;
    final caps = m.caps.setting(MemberCaps.archetype, archetypeId);
    await db.membersDao.updateCapabilities(memberId, caps.toJson());
  }

  // Cert add/remove + expiry moved to CertActions in
  // lib/features/certifications/certifications_providers.dart now that
  // certifications are a first-class entity (UX_DECISIONS §8).
}

final memberCapActionsProvider = Provider<MemberCapActions>(
  MemberCapActions.new,
);

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

  /// Set or clear an integer cap. Stored as a JSON number so `getInt`
  /// reads it straight back (a string-stored int would not). Pass
  /// `value: null` to remove the key.
  Future<void> setIntCap(String spaceId, String key, int? value) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final s = await db.spacesDao.findById(spaceId);
    if (s == null) return;
    final caps = s.caps.setting(key, value);
    await db.spacesDao.updateCapabilities(spaceId, caps.toJson());
  }
}

final spaceCapActionsProvider = Provider<SpaceCapActions>(SpaceCapActions.new);

/// String caps on a Group (a room) — e.g. the room's theme skin
/// (docs/VISION.md "two layers of skin"). Groups have no findById/
/// updateCapabilities DAO, so this reads via watchById + writes via update_.
class GroupCapActions {
  GroupCapActions(this._ref);

  final Ref _ref;

  Future<void> setStringCap(String groupId, String key, String? value) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final g = await db.groupsDao.watchById(groupId).first;
    if (g == null) return;
    final caps = g.caps.setting(key, value);
    await db.groupsDao.update_(id: groupId, capabilitiesJson: caps.toJson());
  }
}

final groupCapActionsProvider = Provider<GroupCapActions>(GroupCapActions.new);
