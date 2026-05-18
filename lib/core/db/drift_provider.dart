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
  return db.watchMember(session.user.id);
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
  return db.watchSpace(spaceId);
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
  return db.watchGuardianForUser(session.user.id);
});

/// The list of children the signed-in guardian is linked to. Empty
/// for anyone but a guardian. Re-emits when subject_guardians changes.
final myChildrenProvider = StreamProvider<List<Subject>>((ref) {
  final guardian = ref.watch(currentGuardianProvider).value;
  final dbAsync = ref.watch(appDatabaseProvider);
  final db = dbAsync.value;
  if (guardian == null || db == null) return Stream<List<Subject>>.value([]);
  return db.watchChildrenForGuardian(guardian.id);
});

/// Live view of any Member by ID. Drives "who's driving" labels and
/// similar callsites. Cheap because each Member row is small; safe to
/// have many concurrent subscriptions (autoDispose tears down idle ones).
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final memberByIdProvider =
    StreamProvider.autoDispose.family<Member?, String>((ref, id) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.watchMember(id);
});
