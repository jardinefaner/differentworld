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
final currentSpaceProvider = StreamProvider<Space?>((ref) {
  final spaceId = ref.watch(currentMemberProvider).value?.spaceId;
  final dbAsync = ref.watch(appDatabaseProvider);
  final db = dbAsync.value;
  if (spaceId == null || db == null) return Stream<Space?>.value(null);
  return db.watchSpace(spaceId);
});
