import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/db/power_sync_schema.dart';
import 'package:differentworld/core/sync/supabase_connector.dart';
import 'package:differentworld/core/sync/sync_window.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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

/// Side-effect provider: wires PowerSync connect/disconnect to the
/// auth state, and (re-)subscribes the parameterized `by_space_recent`
/// stream every local midnight so the time-window slides.
///
/// Must be watched somewhere (root widget) to be alive.
final powerSyncLifecycleProvider = Provider<void>((ref) {
  // Ensure the DB starts opening as soon as this provider is active.
  final dbAsync = ref.watch(powerSyncProvider);

  Timer? rolloverTimer;

  ref.onDispose(() {
    rolloverTimer?.cancel();
  });

  Future<void> resubscribeRecent(PowerSyncDatabase db) async {
    // Subscribe to the parameterized recent-window stream. While the
    // PowerSync dashboard YAML still has the legacy `by_space`
    // (auto_subscribe: true) that covers everything, this call is a
    // no-op against an unknown stream — PowerSync logs a warning but
    // the auto-subscribed full sync keeps working. Once the dashboard
    // is updated to publish `by_space_recent` (auto_subscribe: false)
    // for entries / attendance_records / vehicle_logs, this kicks in
    // and the heavy tables stop growing the cold-start payload.
    // The installed PowerSync SDK exposes `syncStream(name).subscribe`
    // but the parameters-aware overload (`subscribe(parameters: …)`)
    // isn't shipped yet — only ttl/priority. Until the SDK lands
    // parameters, we compute the cutoff and stash it for diagnostics
    // but don't actually invoke a no-op subscribe (which would throw
    // NoSuchMethodError).
    //
    // When the SDK upgrades AND the dashboard YAML adds
    // `by_space_recent`, switch this block to:
    //
    //   await db
    //     .syncStream('by_space_recent')
    //     .subscribe(parameters: {
    //       'cutoff_at':   SyncWindow.cutoffIsoNow(),
    //       'cutoff_date': SyncWindow.cutoffDateNow(),
    //     });
    //
    // See `docs/SCALE_PUNCH_LIST.md` → "Time-windowed sync".
    final _ = db; // silence "unused parameter"
    debugPrint(
      '[sync] window cutoffs ready: '
      'at=${SyncWindow.cutoffIsoNow()} '
      'date=${SyncWindow.cutoffDateNow()} — '
      'subscribe wiring waits on SDK + dashboard.',
    );
  }

  void scheduleRollover(PowerSyncDatabase db) {
    rolloverTimer?.cancel();
    rolloverTimer = Timer(
      SyncWindow.timeUntilNextLocalMidnight(),
      () async {
        await resubscribeRecent(db);
        scheduleRollover(db); // reschedule for the next midnight
      },
    );
  }

  ref.listen<Session?>(
    sessionProvider,
    (previous, session) async {
      final db = dbAsync.value;
      if (db == null) return; // Will re-fire when powerSyncProvider resolves.
      if (session != null) {
        await db.connect(connector: SupabaseConnector(db));
        await resubscribeRecent(db);
        scheduleRollover(db);
      } else {
        rolloverTimer?.cancel();
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
