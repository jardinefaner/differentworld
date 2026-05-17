import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/power_sync_schema.dart';
import 'package:differentworld/core/sync/supabase_connector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;

Future<String> _resolveDbPath() async {
  if (kIsWeb) return 'differentworld.db';
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'differentworld.db');
}

/// Opens the local PowerSync SQLite database once for the app's lifetime.
/// The instance stays open across sign-in/sign-out cycles; only
/// `connect()` / `disconnect()` change as auth state flips.
final powerSyncProvider = FutureProvider<PowerSyncDatabase>((ref) async {
  final path = await _resolveDbPath();
  final db = PowerSyncDatabase(schema: appSchema, path: path);
  await db.initialize();
  ref.onDispose(() async {
    await db.disconnect();
    await db.close();
  });
  return db;
});

/// Side-effect provider: wires PowerSync connect/disconnect to the auth
/// state. Must be watched somewhere (root widget) to be alive.
final powerSyncLifecycleProvider = Provider<void>((ref) {
  // Ensure the DB starts opening as soon as this provider is active.
  final dbAsync = ref.watch(powerSyncProvider);

  ref.listen<Session?>(
    sessionProvider,
    (previous, session) async {
      final db = dbAsync.value;
      if (db == null) return; // Will re-fire when powerSyncProvider resolves.
      if (session != null) {
        await db.connect(connector: SupabaseConnector(db));
      } else {
        await db.disconnect();
      }
    },
    fireImmediately: true,
  );
});

/// Live sync status from PowerSync. Empty stream until the DB is open.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final dbAsync = ref.watch(powerSyncProvider);
  final db = dbAsync.value;
  if (db == null) return const Stream<SyncStatus>.empty();
  return db.statusStream;
});
