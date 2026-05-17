import 'package:differentworld/core/env/env.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bridges PowerSync ↔ Supabase.
///
/// - `fetchCredentials` hands PowerSync the Supabase JWT, which PowerSync
///   verifies against the JWT secret configured in the instance dashboard.
/// - `uploadData` applies the local CRUD queue to Supabase. RLS on Supabase
///   is the gatekeeper — writes that fail RLS will throw and be retried.
class SupabaseConnector extends PowerSyncBackendConnector {
  SupabaseConnector(this.db);

  final PowerSyncDatabase db;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      // Not signed in — PowerSync will retry once the auth state changes.
      return null;
    }
    return PowerSyncCredentials(
      endpoint: Env.powerSyncUrl,
      token: session.accessToken,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    try {
      for (final op in transaction.crud) {
        final table = _supabase.from(op.table);
        switch (op.op) {
          case UpdateType.put:
            await table.upsert(<String, dynamic>{
              'id': op.id,
              ...?op.opData,
            });
          case UpdateType.patch:
            await table.update(op.opData ?? <String, dynamic>{}).eq('id', op.id);
          case UpdateType.delete:
            await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } on Exception {
      // Don't `complete()` — PowerSync keeps the transaction in the queue
      // and retries on the next cycle. Rethrow so PowerSync logs it.
      // If a row is permanently RLS-rejected this will retry forever;
      // we'll add a poison-pill policy when we hit it in practice.
      rethrow;
    }
  }
}
