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

/// Reactive view of the signed-in user's own profile row. Emits null
/// while the row hasn't been pulled from Supabase yet; emits a `Profile`
/// once it arrives. Resets to null on sign-out.
final currentProfileProvider = StreamProvider<Profile?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return Stream<Profile?>.value(null);
  final dbAsync = ref.watch(appDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) return Stream<Profile?>.value(null);
  return db.watchProfile(session.user.id);
});

/// Convenience: has the user finished onboarding (created or joined a
/// program)? Used by the router/Home to decide which screen to show.
final hasProgramProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentProfileProvider);
  final profile = profileAsync.value;
  return profile != null && profile.programId != null;
});
