import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// Drives the family-side viewer resolution.
final currentGuardianProvider = StreamProvider<Guardian?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return Stream<Guardian?>.value(null);
  final dbAsync = ref.watch(appDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) return Stream<Guardian?>.value(null);
  return db.guardiansDao.watchForUser(session.user.id);
});

/// IDs of the children the signed-in guardian is linked to. Offline-
/// first: reads the local `subject_guardians` mirror (delivered by
/// the `by_guardian` PowerSync stream — see `supabase/sync_rules.yaml`).
///
/// Used by `viewerProvider` to seed `GuardianViewer.childSubjectIds`
/// without a PostgREST round-trip. Full `Subject` rows for these IDs
/// come from `familyChildrenProvider` (PostgREST) in
/// `lib/features/family/family_providers.dart` — `subjects` themselves
/// don't sync to a guardian's device under the current narrow
/// `by_guardian` scope.
///
/// Empty for staff viewers — they have no guardian row.
final myChildSubjectIdsProvider = StreamProvider<List<String>>((ref) {
  final guardian = ref.watch(currentGuardianProvider).value;
  final dbAsync = ref.watch(appDatabaseProvider);
  final db = dbAsync.value;
  if (guardian == null || db == null) {
    return Stream<List<String>>.value(const []);
  }
  // `viewerProvider` watches this stream, so every emission rebuilds
  // the viewer and re-fires every family provider that depends on it.
  // Drift watches re-emit on ANY column write to a matching row — so
  // a touch to `is_primary` or a `created_at` re-stamp would cascade
  // a full PostgREST refetch storm. Dedupe to id-set equality:
  // emit only when the visible kid roster actually changes.
  return (db.select(db.subjectGuardians)
        ..where((sg) => sg.guardianId.equals(guardian.id)))
      .watch()
      .map((rows) => rows.map((r) => r.subjectId).toList())
      .distinct(_listEquals);
});

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
final memberByIdProvider =
    StreamProvider.autoDispose.family<Member?, String>((ref, id) async* {
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
