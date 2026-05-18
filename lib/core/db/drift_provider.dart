import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drift instance wrapping the same SQLite database PowerSync owns.
/// Single shared instance for the app's lifetime.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final powerSync = await ref.watch(powerSyncProvider.future);
  final db = AppDatabase(powerSync);
  ref.onDispose(db.close);

  // Diagnostic: dump what's locally in members + spaces at startup so we
  // can see whether sync actually populated the tables we expect.
  try {
    final allMembers = await db.select(db.members).get();
    debugPrint('[db init] local members: ${allMembers.length} rows');
    for (final m in allMembers) {
      debugPrint(
        '[db init]   member id=${m.id} name=${m.displayName} space=${m.spaceId} role=${m.role}',
      );
    }
    final allSpaces = await db.select(db.spaces).get();
    debugPrint('[db init] local spaces: ${allSpaces.length} rows');
    for (final s in allSpaces) {
      debugPrint('[db init]   space id=${s.id} name=${s.name}');
    }
  } on Object catch (e, st) {
    debugPrint('[db init] failed to dump tables: $e\n$st');
  }

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

  debugPrint(
    '[currentMember] session.user.id=${session.user.id} email=${session.user.email}',
  );
  return db.watchMember(session.user.id).map((m) {
    debugPrint(
      '[currentMember] watch emitted: member=${m?.id} '
      'name=${m?.displayName} space=${m?.spaceId}',
    );
    return m;
  });
});

/// Convenience: has the signed-in user joined a Space (i.e., finished
/// onboarding)? Drives the router gate.
final hasSpaceProvider = Provider<bool>((ref) {
  final memberAsync = ref.watch(currentMemberProvider);
  final m = memberAsync.value;
  return m != null && m.spaceId != null;
});
