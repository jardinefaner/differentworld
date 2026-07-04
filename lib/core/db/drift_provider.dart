import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Drift instance wrapping the same SQLite database PowerSync owns.
/// Single shared instance for the app's lifetime.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final powerSync = await ref.watch(powerSyncProvider.future);
  final db = AppDatabase(powerSync);
  ref.onDispose(db.close);
  return db;
});

/// Reactive view of the signed-in user's own Member row. Emits null
/// while the row hasn't synced from Supabase yet; emits a `Member` once
/// it arrives. Resets to null on sign-out.
final currentMemberProvider = StreamProvider<Member?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return Stream<Member?>.value(null);
  final dbAsync = ref.watch(appDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) return Stream<Member?>.value(null);
  return db.membersDao.watchById(session.user.id);
});

/// Convenience: has the signed-in user joined a Space (i.e., finished
/// onboarding)? Drives the router gate.
final hasSpaceProvider = Provider<bool>((ref) {
  final memberAsync = ref.watch(currentMemberProvider);
  final m = memberAsync.value;
  return m != null && m.spaceId != null;
});

/// Reactive view of the signed-in user's Space row — the "program" in
/// classroom-app UI. Null while the member hasn't joined a space.
///
/// Resolves the space_id from EITHER the member row (staff path) OR
/// the guardian row (family path), so a guardian also gets the space
/// to display program name etc.
final currentSpaceProvider = StreamProvider<Space?>((ref) {
  final memberSpaceId = ref.watch(currentMemberProvider).value?.spaceId;
  final guardianSpaceId = ref.watch(currentGuardianProvider).value?.spaceId;
  final spaceId = memberSpaceId ?? guardianSpaceId;
  final dbAsync = ref.watch(appDatabaseProvider);
  final db = dbAsync.value;
  if (spaceId == null || db == null) return Stream<Space?>.value(null);
  return db.spacesDao.watchById(spaceId);
});

/// Reactive view of the signed-in user's Guardian row, if they have
/// one. Returns null for staff (Members) or anyone not yet linked.
/// Drives the family-side viewer resolution in `viewerProvider`.
///
/// **Hybrid lookup** (Wave 45): the local Drift mirror is the primary
/// source — offline-first, live-updating when `subject_guardians`
/// changes elsewhere. But on a guardian's FIRST sign-in after
/// redeeming an invite, the local mirror is empty until the
/// `by_guardian` PowerSync stream catches up (and that stream only
/// exists once the YAML in `supabase/sync_rules.yaml` has been
/// redeployed on the PowerSync dashboard — repo file ≠ runtime).
///
/// If Drift emits null on first subscription, we fire a one-shot
/// direct PostgREST fetch as a fallback. This way:
///   * Dashboard deployed → Drift wins → offline-first, live updates.
///   * Dashboard not yet deployed → PostgREST returns the row → the
///     family path lights up immediately; once dashboard catches up
///     the watch stream takes over without a re-mount.
///   * Staff user (no guardian row) → both sources return null → the
///     viewer falls through to the staff path. Cost of the fallback
///     for staff is one extra round-trip per sign-in.
final currentGuardianProvider = StreamProvider<Guardian?>((ref) async* {
  final session = ref.watch(sessionProvider);
  if (session == null) {
    yield null;
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  final userId = session.user.id;
  final driftStream = db.guardiansDao.watchForUser(userId);

  // First emission from Drift. If non-null, we're done — the row is
  // present in the local mirror, the `by_guardian` stream is wired,
  // continue watching from the second emission onward (skip(1) so we
  // don't double-yield the first row).
  final first = await driftStream.first;
  if (first != null) {
    yield first;
    yield* driftStream.skip(1);
    return;
  }

  // Drift empty. Two possibilities — we can short-circuit one of them
  // by checking the local member row: if the user has a member row
  // with a non-null space_id, they're confirmed staff and definitely
  // not a guardian, so we can skip the PostgREST round-trip entirely.
  // (Guardians' member.space_id stays null.) Saves a guardians-table
  // GET on every staff cold-start (preflight perf WARNING).
  final localMember = await db.membersDao.watchById(userId).first;
  if (localMember != null && localMember.spaceId != null) {
    yield null;
    // No watch on the staff side — guardian row can't appear later
    // for someone who's already in a space as staff. Done.
    return;
  }

  // Drift empty AND no staff-confirmation. Try direct PostgREST as
  // a fallback — either we get a row (the user IS a guardian; the
  // by_guardian stream just hasn't delivered yet) or we get null
  // (the user isn't a guardian and we fall through to the staff
  // path with no guardian).
  final fromPostgrest = await _fetchGuardianFromPostgrest(userId);
  yield fromPostgrest;

  // Keep watching Drift in case the stream eventually delivers — but
  // FILTER OUT trailing nulls. Without the filter, Drift's cold
  // re-subscription immediately emits null (the mirror still hasn't
  // synced) which would cascade back through `viewerProvider` →
  // `_Home` → bounce a freshly-onboarded guardian to JoinOrCreate
  // (preflight BLOCKER). Once Drift delivers a real row we let it
  // supersede the PostgREST fallback; a deletion (guardian revoked)
  // is the only case we'd lose visibility on, and that's acceptable
  // for the interim until the dashboard redeploy lands.
  yield* driftStream.where((g) => g != null);
});

/// One-shot fetch of `public.guardians` for the signed-in user via
/// direct PostgREST. Used by [currentGuardianProvider] as a fallback
/// when the local Drift mirror is empty (e.g. the `by_guardian`
/// PowerSync stream isn't yet deployed). Returns null if the user
/// isn't a guardian OR the network call fails — we don't want to
/// throw out of a viewer-resolution path.
Future<Guardian?> _fetchGuardianFromPostgrest(String userId) async {
  try {
    final supabase = Supabase.instance.client;
    final row = await supabase
        .from('guardians')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return _guardianFromMap(row);
  } on Object catch (e, st) {
    if (kDebugMode) {
      debugPrint('[guardian-fallback] postgrest fetch failed: $e\n$st');
    }
    return null;
  }
}

/// PostgREST JSON map → Drift Guardian. Mirrors the structure of the
/// `Guardians` table in `app_database.dart`. Kept here next to the
/// fetch helper so the round-trip-and-decode lives in one place.
Guardian _guardianFromMap(Map<String, dynamic> r) => Guardian(
  id: r['id'] as String,
  spaceId: r['space_id'] as String,
  userId: r['user_id'] as String?,
  name: r['name'] as String,
  relationship: r['relationship'] as String?,
  phone: r['phone'] as String?,
  email: r['email'] as String?,
  authorizedForPickup: r['authorized_for_pickup'] is bool
      ? ((r['authorized_for_pickup'] as bool) ? 1 : 0)
      : r['authorized_for_pickup'] as int?,
  notes: r['notes'] as String?,
  createdAt: r['created_at'] as String,
  updatedAt: r['updated_at'] as String,
);

/// IDs of the children the signed-in guardian is linked to.
///
/// **Hybrid lookup** (Wave 46, parallel shape to Wave 45's guardian
/// fallback): primary source is the local `subject_guardians` mirror
/// delivered by the `by_guardian` PowerSync stream (see
/// `supabase/sync_rules.yaml`). If the dashboard hasn't been
/// redeployed with the new stream — or hasn't synced yet on a freshly
/// onboarded guardian device — the mirror is empty and every
/// `viewer.canSeeSubject(...)` check returns false, leaving the
/// family lens with no kids visible. Fallback: one-shot direct
/// PostgREST query on `subject_guardians` filtered by the guardian's
/// id. Once Drift catches up, the watch supersedes.
///
/// `viewerProvider` watches this stream, so every emission rebuilds
/// the viewer + re-fires every family provider that depends on it.
/// Drift watches re-emit on ANY column write to a matching row — so
/// a touch to `is_primary` or a `created_at` re-stamp would cascade
/// a full PostgREST refetch storm. Dedupe to id-set equality: emit
/// only when the visible kid roster actually changes.
///
/// Empty for staff viewers — they have no guardian row.
final myChildSubjectIdsProvider = StreamProvider<List<String>>((ref) async* {
  final guardian = ref.watch(currentGuardianProvider).value;
  final dbAsync = ref.watch(appDatabaseProvider);
  final db = dbAsync.value;
  if (guardian == null || db == null) {
    yield const <String>[];
    return;
  }
  final driftStream =
      (db.select(db.subjectGuardians)
            ..where((sg) => sg.guardianId.equals(guardian.id)))
          .watch()
          .map((rows) => rows.map((r) => r.subjectId).toList())
          .distinct(_listEquals);

  // First Drift emission. If non-empty, we're offline-first — yield
  // and continue watching from the second emission (skip(1)).
  final first = await driftStream.first;
  if (first.isNotEmpty) {
    yield first;
    yield* driftStream.skip(1);
    return;
  }

  // Drift empty. Either: (a) the by_guardian stream hasn't delivered
  // subject_guardians for this guardian yet, or (b) the guardian
  // really has no linked children. Try direct PostgREST to
  // disambiguate.
  final fromPostgrest = await _fetchSubjectIdsForGuardian(guardian.id);
  yield fromPostgrest;

  // Wave 102 (Red Team #8): the old behavior was
  // `.where((ids) => ids.isNotEmpty)` — designed to stop Drift from
  // clobbering the PostgREST-resolved roster with a stale `[]` cold
  // emission. The side effect: a director unlinking a guardian's
  // last child mid-session would never propagate (Drift correctly
  // emits `[]`, the filter drops it, the guardian keeps seeing the
  // unlinked child until cold launch — a privacy violation).
  //
  // Fix: only suppress empty emissions UNTIL Drift has delivered at
  // least one non-empty list. After that, empty emissions are real
  // (an unlink) and must propagate so viewerProvider updates.
  var sawNonEmpty = false;
  yield* driftStream.where((ids) {
    if (ids.isNotEmpty) {
      sawNonEmpty = true;
      return true;
    }
    return sawNonEmpty;
  });
});

/// One-shot fetch of `subject_guardians.subject_id` rows for the
/// guardian via direct PostgREST. Used by [myChildSubjectIdsProvider]
/// as a fallback when the local Drift mirror is empty (the
/// `by_guardian` stream isn't yet delivering). Returns `[]` on any
/// failure — viewer-resolution paths must never throw.
Future<List<String>> _fetchSubjectIdsForGuardian(String guardianId) async {
  try {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('subject_guardians')
        .select('subject_id')
        .eq('guardian_id', guardianId);
    return [
      for (final r in rows)
        if (r['subject_id'] != null) r['subject_id'] as String,
    ];
  } on Object catch (e, st) {
    if (kDebugMode) {
      debugPrint(
        '[children-fallback] postgrest fetch failed: $e\n$st',
      );
    }
    return const <String>[];
  }
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Live view of any Member by ID. Drives "who's driving" labels and
/// similar callsites. Cheap because each Member row is small; safe to
/// have many concurrent subscriptions (autoDispose tears down idle ones).
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final memberByIdProvider = StreamProvider.autoDispose.family<Member?, String>((
  ref,
  id,
) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.membersDao.watchById(id);
});

/// Every Member in the signed-in user's space — drives the "lead"
/// dropdown on a schedule block, the team page, and other places that
/// need to enumerate staff. Excludes guardian-only viewers; returns
/// `[]` if the user hasn't joined a space yet.
final membersInSpaceProvider = StreamProvider<List<Member>>((ref) {
  final spaceId = ref.watch(currentMemberProvider).value?.spaceId;
  final db = ref.watch(appDatabaseProvider).value;
  if (spaceId == null || db == null) {
    return Stream<List<Member>>.value(const []);
  }
  return db.membersDao.watchInSpace(spaceId);
});
